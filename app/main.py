import time
import random
import threading
import os
from fastapi import FastAPI, Response, Request
from prometheus_client import Counter, Histogram, Gauge, generate_latest, CONTENT_TYPE_LATEST
import psutil

app = FastAPI(title="TechStream Self-Healing Demo")

# --- Golden Signal Metrics ---
REQUEST_COUNT = Counter(
    "http_requests_total",
    "Total HTTP requests",
    ["method", "endpoint", "status"],
)
REQUEST_LATENCY = Histogram(
    "http_request_duration_seconds",
    "HTTP request latency in seconds",
    ["endpoint"],
    buckets=[0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1.0, 2.5, 5.0],
)
CPU_USAGE = Gauge("cpu_usage_percent", "CPU usage percentage")
MEMORY_USAGE = Gauge("memory_usage_percent", "Memory usage percentage")
ERROR_RATE_GAUGE = Gauge("configured_error_rate", "Currently injected error rate (chaos)")

# --- Chaos state (shared mutable dict — simple enough for a single-process demo) ---
chaos = {"error_rate": 0.0, "cpu_spiking": False}


def _collect_system_metrics():
    while True:
        CPU_USAGE.set(psutil.cpu_percent(interval=1))
        MEMORY_USAGE.set(psutil.virtual_memory().percent)
        time.sleep(5)


threading.Thread(target=_collect_system_metrics, daemon=True).start()


# --- Request middleware: latency + error injection ---
@app.middleware("http")
async def instrument(request: Request, call_next):
    start = time.time()
    path = request.url.path

    # Inject synthetic 500s on API routes when chaos is active
    if path.startswith("/api") and random.random() < chaos["error_rate"]:
        duration = time.time() - start
        REQUEST_LATENCY.labels(endpoint=path).observe(duration)
        REQUEST_COUNT.labels(method=request.method, endpoint=path, status="500").inc()
        return Response(content='{"detail":"Internal Server Error"}', status_code=500,
                        media_type="application/json")

    response = await call_next(request)
    duration = time.time() - start
    REQUEST_LATENCY.labels(endpoint=path).observe(duration)
    REQUEST_COUNT.labels(
        method=request.method, endpoint=path, status=str(response.status_code)
    ).inc()
    return response


# --- Normal application endpoints ---
@app.get("/")
def root():
    return {"service": "TechStream API", "status": "healthy"}


@app.get("/health")
def health():
    return {"status": "ok", "cpu": psutil.cpu_percent(), "memory": psutil.virtual_memory().percent}


@app.get("/api/products")
def get_products():
    time.sleep(random.uniform(0.01, 0.1))
    return {"products": ["Widget A", "Widget B", "Widget C"]}


@app.get("/api/orders")
def get_orders():
    time.sleep(random.uniform(0.05, 0.2))
    return {"orders": [{"id": 1, "status": "shipped"}, {"id": 2, "status": "pending"}]}


@app.get("/api/users")
def get_users():
    time.sleep(random.uniform(0.02, 0.08))
    return {"users": [{"id": 1, "name": "Alice"}, {"id": 2, "name": "Bob"}]}


# --- Prometheus metrics endpoint ---
@app.get("/metrics")
def metrics():
    return Response(content=generate_latest(), media_type=CONTENT_TYPE_LATEST)


# --- Chaos engineering endpoints ---
@app.post("/chaos/errors")
def inject_errors(rate: float = 0.6):
    """Set synthetic HTTP 500 error rate on /api/* routes. rate=0.0 to 1.0."""
    chaos["error_rate"] = max(0.0, min(1.0, rate))
    ERROR_RATE_GAUGE.set(chaos["error_rate"])
    return {"chaos": "errors", "rate": chaos["error_rate"], "message": f"Injecting {rate*100:.0f}% errors"}


@app.post("/chaos/cpu")
def spike_cpu(duration: int = 60):
    """Burn CPU in a background thread for `duration` seconds."""
    def burn():
        chaos["cpu_spiking"] = True
        end = time.time() + duration
        while time.time() < end:
            _ = [x ** 2 for x in range(50_000)]
        chaos["cpu_spiking"] = False

    threading.Thread(target=burn, daemon=True).start()
    return {"chaos": "cpu", "duration_seconds": duration, "message": f"CPU spike started for {duration}s"}


@app.delete("/chaos")
def reset_chaos():
    """Reset all chaos injections — used by the auto-remediation webhook."""
    chaos["error_rate"] = 0.0
    chaos["cpu_spiking"] = False
    ERROR_RATE_GAUGE.set(0.0)
    return {"chaos": "reset", "message": "All chaos cleared — system nominal"}

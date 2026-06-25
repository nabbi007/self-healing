#!/usr/bin/env python3
"""
TechStream Chaos Script
=======================

Drives load at the web service and injects failures so the CloudWatch
error-rate alarm trips and the self-healing pipeline kicks in.

Uses only the Python standard library — no pip install required.

Examples
--------
  # Inject 60% HTTP 500s and hammer the API for 5 minutes
  python chaos.py --url http://my-alb-123.eu-central-1.elb.amazonaws.com errors

  # Spike CPU on the instances for 120 seconds
  python chaos.py --url http://my-alb-... cpu --duration 120

  # Just generate clean baseline traffic (no failures)
  python chaos.py --url http://my-alb-... traffic

  # Clear all injected chaos
  python chaos.py --url http://my-alb-... reset
"""

import argparse
import threading
import time
import urllib.request
import urllib.error
from concurrent.futures import ThreadPoolExecutor

API_PATHS = ["/api/products", "/api/orders", "/api/users"]


def _request(url, method="GET", timeout=5):
    req = urllib.request.Request(url, method=method)
    try:
        with urllib.request.urlopen(req, timeout=timeout) as resp:
            return resp.status
    except urllib.error.HTTPError as e:
        return e.code
    except Exception:
        return 0  # connection error / timeout


def generate_traffic(base_url, duration, rps, stop_event, stats):
    """Continuously fire requests at the API until duration elapses."""
    end = time.time() + duration
    delay = 1.0 / max(rps, 1)
    path_idx = 0

    def worker():
        nonlocal path_idx
        while time.time() < end and not stop_event.is_set():
            path = API_PATHS[path_idx % len(API_PATHS)]
            path_idx += 1
            status = _request(base_url + path)
            with stats["lock"]:
                stats["total"] += 1
                if status >= 500 or status == 0:
                    stats["errors"] += 1
            time.sleep(delay)

    with ThreadPoolExecutor(max_workers=10) as pool:
        for _ in range(10):
            pool.submit(worker)


def _print_stats_loop(stop_event, stats):
    while not stop_event.is_set():
        time.sleep(5)
        with stats["lock"]:
            total = stats["total"]
            errors = stats["errors"]
        rate = (100 * errors / total) if total else 0
        print(f"  [traffic] sent={total:<6} errors={errors:<6} error_rate={rate:5.1f}%")


def cmd_errors(args):
    print(f"==> Injecting {args.rate*100:.0f}% HTTP 500 errors on {args.url}")
    body = _post_with_query(args.url + "/chaos/errors", {"rate": args.rate})
    print(f"    server: {body}")
    _run_traffic_phase(args, label="errors injected")


def cmd_cpu(args):
    print(f"==> Spiking CPU on {args.url} for {args.duration}s")
    body = _post_with_query(args.url + "/chaos/cpu", {"duration": args.duration})
    print(f"    server: {body}")
    _run_traffic_phase(args, label="cpu spiking")


def cmd_traffic(args):
    print(f"==> Generating clean baseline traffic on {args.url}")
    _run_traffic_phase(args, label="baseline")


def cmd_reset(args):
    print(f"==> Clearing all chaos on {args.url}")
    body = _request(args.url + "/chaos", method="DELETE")
    print(f"    server returned status {body}")


def _post_with_query(url, params):
    query = "&".join(f"{k}={v}" for k, v in params.items())
    full = f"{url}?{query}"
    req = urllib.request.Request(full, method="POST")
    try:
        with urllib.request.urlopen(req, timeout=5) as resp:
            return resp.read().decode()
    except urllib.error.HTTPError as e:
        return f"HTTP {e.code}: {e.read().decode()}"
    except Exception as e:
        return f"error: {e}"


def _run_traffic_phase(args, label):
    stats = {"total": 0, "errors": 0, "lock": threading.Lock()}
    stop_event = threading.Event()

    reporter = threading.Thread(target=_print_stats_loop, args=(stop_event, stats), daemon=True)
    reporter.start()

    print(f"    driving load for {args.duration}s at ~{args.rps} req/s ({label})")
    print("    watch the CloudWatch dashboard — alarm trips when error rate > 5%")
    try:
        generate_traffic(args.url, args.duration, args.rps, stop_event, stats)
    except KeyboardInterrupt:
        print("\n    interrupted")
    finally:
        stop_event.set()

    with stats["lock"]:
        total, errors = stats["total"], stats["errors"]
    rate = (100 * errors / total) if total else 0
    print(f"\n==> Done. total={total} errors={errors} final_error_rate={rate:.1f}%")


def main():
    parser = argparse.ArgumentParser(description="TechStream chaos injector")
    parser.add_argument("--url", required=True, help="Base URL of the ALB / app")

    # Shared options, attached to each subcommand so they may be given AFTER it
    # (e.g. `chaos.py --url X errors --rate 0.7 --duration 300`).
    common = argparse.ArgumentParser(add_help=False)
    common.add_argument("--duration", type=int, default=300, help="Seconds to run (default 300)")
    common.add_argument("--rps", type=int, default=20, help="Approx requests/sec (default 20)")
    common.add_argument("--rate", type=float, default=0.6, help="Error injection rate 0..1 (errors cmd)")

    sub = parser.add_subparsers(dest="command", required=True)
    sub.add_parser("errors", parents=[common], help="Inject HTTP 500s then drive traffic")
    sub.add_parser("cpu", parents=[common], help="Spike CPU then drive traffic")
    sub.add_parser("traffic", parents=[common], help="Generate clean baseline traffic")
    sub.add_parser("reset", parents=[common], help="Clear all injected chaos")

    args = parser.parse_args()
    args.url = args.url.rstrip("/")

    {
        "errors": cmd_errors,
        "cpu": cmd_cpu,
        "traffic": cmd_traffic,
        "reset": cmd_reset,
    }[args.command](args)


if __name__ == "__main__":
    main()

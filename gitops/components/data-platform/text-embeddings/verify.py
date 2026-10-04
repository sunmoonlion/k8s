#!/usr/bin/env python3
"""Bounded actual CPU embedding acceptance through an authenticated Kubernetes tunnel.
No deployer, model download, credential output or business data writes.
"""
import argparse
import http.client
import json
import math
import os
import re
import selectors
import subprocess
import time


def require(condition, reason):
    if not condition:
        raise RuntimeError(reason)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    for key in ("kubectl", "kubeconfig", "namespace", "model", "revision"):
        parser.add_argument("--" + key, required=True)
    parser.add_argument("--dimensions", type=int, required=True)
    args = parser.parse_args()
    environment = dict(os.environ)
    for key in ("HTTP_PROXY", "HTTPS_PROXY", "ALL_PROXY", "http_proxy", "https_proxy", "all_proxy"):
        environment.pop(key, None)
    environment["NO_PROXY"] = "*"
    prefix = [args.kubectl, "--kubeconfig=" + args.kubeconfig, "--context=kind-sunmoon-kind", "--request-timeout=20s", "-n", args.namespace]
    output = subprocess.run(prefix + ["get", "deployment", "text-embeddings", "-o", "json"], capture_output=True, text=True, env=environment, timeout=30)
    require(output.returncode == 0, "Cannot inspect inference ownership")
    deployment = json.loads(output.stdout)
    require(deployment["spec"]["template"]["metadata"]["annotations"]["sunmoonai.com/model-revision"] == args.revision, "Model revision differs from selection")
    tunnel = subprocess.Popen(prefix + ["port-forward", "--address=127.0.0.1", "service/text-embeddings", "0:8080"], stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, text=True, env=environment)
    try:
        port = None
        with selectors.DefaultSelector() as selector:
            selector.register(tunnel.stdout, selectors.EVENT_READ)
            deadline = time.monotonic() + 20
            while time.monotonic() < deadline and tunnel.poll() is None:
                if selector.select(timeout=0.5):
                    match = re.search(r"Forwarding from 127\.0\.0\.1:(\d+)", tunnel.stdout.readline())
                    if match:
                        port = int(match.group(1))
                        break
        require(port is not None, "Inference management tunnel unavailable")

        def request(method, path, body=None):
            client = http.client.HTTPConnection("127.0.0.1", port, timeout=90)
            try:
                client.request(method, path, body=None if body is None else json.dumps(body, ensure_ascii=False).encode(), headers={"Content-Type": "application/json"})
                response = client.getresponse()
                payload = response.read()
                require(response.status == 200, "Inference HTTP status " + str(response.status))
                return json.loads(payload) if payload else None
            finally:
                client.close()

        request("GET", "/health")
        info = request("GET", "/info")
        require(info.get("version") == "1.9.4", "Running inference version differs from lock")
        require(str(info.get("model_dtype", "")).lower() in ("float32", "f32"), "CPU datatype differs from selection")
        inputs = [
            "Instruct: Given a question, retrieve relevant passages that answer the question.\nQuery:中国的首都是哪里？",
            "中国的首都是北京。北京位于中国北部。",
            "光合作用是植物利用太阳光合成有机物的过程。",
            "Instruct: Given a question, retrieve relevant passages that answer the question.\nQuery:植物如何利用太阳光？",
        ]
        start = time.monotonic()
        result = request("POST", "/v1/embeddings", {"model": args.model, "input": inputs, "encoding_format": "float"})
        duration = time.monotonic() - start
        data = sorted(result["data"], key=lambda row: row["index"])
        require([row["index"] for row in data] == list(range(4)), "Embedding response indexes differ")
        vectors = [row["embedding"] for row in data]
        require(all(len(v) == args.dimensions and all(isinstance(x, (float, int)) and math.isfinite(x) for x in v) for v in vectors), "Embedding dimensions or finite values invalid")
        norms = [math.sqrt(sum(x*x for x in v)) for v in vectors]
        require(all(0.95 <= n <= 1.05 for n in norms), "Embedding output is not normalized")
        def cosine(a,b):
            return sum(x*y for x,y in zip(vectors[a],vectors[b])) / (norms[a]*norms[b])
        require(cosine(0,1) > cosine(0,2), "Chinese capital question did not prefer relevant passage")
        require(cosine(3,2) > cosine(3,1), "Chinese photosynthesis question did not prefer relevant passage")
        native_vectors = request("POST", "/embed", {"inputs": inputs})
        require(len(native_vectors) == len(vectors) and all(len(v) == args.dimensions for v in native_vectors), "RAGFlow native TEI endpoint dimensions differ")
        require(max(abs(a-b) for native, vector in zip(native_vectors, vectors) for a,b in zip(native,vector)) < 0.0001, "Native TEI and OpenAI outputs differ beyond float tolerance")
        repeated = request("POST", "/v1/embeddings", {"model": args.model, "input": [inputs[1]], "encoding_format": "float"})["data"][0]["embedding"]
        require(len(repeated) == args.dimensions and max(abs(a-b) for a,b in zip(repeated,vectors[1])) < 0.0001, "Repeated embedding differs beyond float tolerance")
        print(json.dumps({"passed":True,"model":args.model,"revision":args.revision,"inference_version":info["version"],"device":"CPU","dimensions":args.dimensions,"native_ragflow_protocol":True,"finite_normalized_vectors":True,"chinese_pairwise_relevance":True,"repeatable":True,"batch_seconds":round(duration,3),"scope":"Actual CPU embedding protocol; not RAGFlow ingestion, model benchmark, or application retrieval acceptance"}))
    finally:
        tunnel.terminate()
        try:
            tunnel.wait(timeout=5)
        except subprocess.TimeoutExpired:
            tunnel.kill()
            tunnel.wait()


if __name__ == "__main__":
    try:
        main()
    except Exception as error:
        print(json.dumps({"passed":False,"error":str(error) if isinstance(error,RuntimeError) else type(error).__name__}))
        raise SystemExit(1)

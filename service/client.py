"""nolang service R0 — тонкий Python-клиент. Зовёт долгоживущий вердикт-сервис."""
import socket, json, os

# 🔴 Порт берётся из NOL_PORT. Умолчание 8991, а НЕ 8899: на 8899 живёт uvicorn Луаха,
# и запрос туда возвращает HTTP 400 — клиент падал с JSONDecodeError, что читается как
# «nolang сломан». Правило: умолчание клиента обязано совпадать с тем, на чём поднят сервис.
ПОРТ_ПО_УМОЛЧАНИЮ = int(os.environ.get("NOL_PORT", "8991"))

def judge(program, prelude=None, require=None, host="127.0.0.1", port=None, timeout=15):
    port = ПОРТ_ПО_УМОЛЧАНИЮ if port is None else port
    s = socket.create_connection((host, port), timeout=timeout)
    f = s.makefile("rw", encoding="utf-8", newline="\n")
    if require: f.write(f"REQUIRE: {require}\n")
    if prelude:
        f.write("===PRELUDE===\n"); f.write(prelude)
        if not prelude.endswith("\n"): f.write("\n")
    f.write("===PROGRAM===\n"); f.write(program)
    if not program.endswith("\n"): f.write("\n")
    f.write("===END===\n"); f.flush()
    resp = f.readline()
    s.close()
    return json.loads(resp)

if __name__ == "__main__":
    import sys, time
    prog = sys.stdin.read()
    t0 = time.time()
    v = judge(prog)
    dt = (time.time()-t0)*1000
    print(json.dumps(v, ensure_ascii=False), f"[{dt:.1f} ms]")


# ── R0.3: впрыск свидетельств из СТРУКТУРНЫХ данных мира (выход LLM, источники) ──
# Не литеральный .nol — Python собирает программу-политику из evidence+policy+claim+gate.
# Сборка детерминирована (чистая строка того же языка) — не вторая истина.
def build_program(evidence, policy="", claim=None, gate=None, lattice=None):
    L = lattice or "lattice provenance = silence < image < tradition < strict"
    out = [L, ""]
    for e in evidence:
        _says = str(e.get("says","")).replace(chr(34)," ").replace(chr(10)," ").replace(chr(13)," ")[:120]
        out += [f'witness {e["id"]} : {e.get("grade","strict")}',
                f'  says "{_says}"',
                f'  source {e.get("source","src")}',
                f'  evidence {int(e.get("for",1))} for {int(e.get("against",0))} against', ""]
    if policy:
        out += [policy, ""]
    if claim:
        cid, grade = claim["id"], claim.get("grade", "strict")
        if "rule" in claim:
            out += [f'claim {cid} : {grade} = {claim["rule"]}({", ".join(claim["args"])})', ""]
        else:
            out += [f'claim {cid} : {grade} from {", ".join(claim["from"])}', ""]
    if gate and claim:
        act, thr = gate["action"], gate.get("threshold", 0.7)
        out += [f'irreversible action {act}', f'  needs grade >= strict',
                f'  gated by belief >= {thr}', f'  else fold',
                f'perform {act} on {claim["id"]}']
    return "\n".join(out)

def judge_evidence(evidence, policy="", claim=None, gate=None, require=None, **kw):
    """Структурные данные мира → вердикт+провенанс. require по умолчанию = имя действия гейта."""
    prog = build_program(evidence, policy, claim, gate)
    if require is None and gate:
        require = gate["action"]
    return judge(prog, require=require, **kw)


# ── R3.2: .nlib политики-библиотеки (ТУЛИНГ, не язык — загрузчик собирает правила) ──
import os, re
NLIB_DIR = os.environ.get("NOL_LIB", os.path.join(os.path.dirname(__file__), "..", "lib"))
def load_nlib(name, libdir=None, pin=None):
    """Читает <name>.nlib → (source, version). pin: если задан, версия обязана совпасть (aObj0-непрерывность)."""
    path = os.path.join(libdir or NLIB_DIR, f"{name}.nlib")
    with open(path, encoding="utf-8") as f:
        src = f.read()
    m = re.search(r"@nlib\s+\S+\s+version\s+(\S+)", src)
    version = m.group(1) if m else None
    if pin is not None and version != pin:
        raise ValueError(f"nlib {name}: версия {version} ≠ закреплённой {pin} (несовместимая политика)")
    return src, version

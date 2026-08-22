"""R1 — харнесс «nolang валидирует LLM-выход». Переиспользуемый шов нейросимволики:
(выход LLM + источники) → свидетели → политика nolang → вердикт → решение {emit|ask|refuse}.
Оборачивает сервис; вся семантика — в nolang, не здесь."""
from client import judge_evidence

class NolangValidator:
    def __init__(self, threshold=0.7, action="emit", policy="", rule=None, port=8991):
        self.threshold=threshold; self.action=action
        self.policy=policy; self.rule=rule; self.port=port

    def validate(self, llm_output, sources, claim_id="answer"):
        """sources: [{id, for, against, says?, source?, grade?}] — источники как свидетели.
        Возвращает {decision, verdict, belief, threshold, reason, provenance}."""
        ev = [{"id":s["id"],"grade":s.get("grade","strict"),
               "says":s.get("says", (llm_output or "")[:70]),
               "source":s.get("source","src"),
               "for":s.get("for",1),"against":s.get("against",0)} for s in sources]
        ids = [s["id"] for s in sources]
        if self.rule:
            claim = {"id":claim_id,"grade":"strict","rule":self.rule,"args":ids}
        else:
            claim = {"id":claim_id,"grade":"strict","from":ids}
        gate = {"action":self.action,"threshold":self.threshold}
        v = judge_evidence(ev, self.policy, claim, gate, port=self.port)
        prov = v.get("provenance", [])
        perf = next((p for p in prov if p.get("kind") in ("performed","compensating")), None)
        fold = next((p for p in prov if p.get("kind")=="folded"), None)
        flaw = next((p for p in prov if p.get("kind") in
                     ("orphaned","irreparable","unauthorized","compensation-folded")), None)
        belief = (perf or fold or {}).get("belief")
        if v["verdict"] == "ДОПУЩЕНО" and perf:
            decision, reason = "emit", "свидетели сошлись, вера ≥ порог"
        elif flaw:
            decision, reason = "refuse", f"порок: {flaw.get('kind')}"
        elif fold:
            decision = "refuse"
            reason = f"вера {fold['belief']} < порог {fold['threshold']} — отказать (нет опоры)"
        else:
            decision, reason = "refuse", v.get("reason","")
        return {"decision":decision, "verdict":v["verdict"], "belief":belief,
                "threshold":self.threshold, "reason":reason, "provenance":prov}

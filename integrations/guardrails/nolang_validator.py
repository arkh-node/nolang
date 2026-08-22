"""Guardrails-адаптер nolang — детерминированный, аудируемый валидатор LLM-выхода.

Встраивается в Guardrails AI как кастомный Validator (их же механизм: класс от base Validator +
@register_validator). Проверяет выход LLM против ИСТОЧНИКОВ через nolang-сервис и возвращает
Pass/Fail с провенансом (почему). Ров: вердикт детерминирован и объясним, а не ML-«обычно».

Работает и БЕЗ установленного guardrails (совместимые заглушки-интерфейсы) — тогда `validate`
возвращает совместимый по форме результат; при установленном guardrails — настоящие Pass/FailResult.

Использование (в guardrails):
    from guardrails import Guard
    guard = Guard().use(NolangFaithful, threshold=0.7, on_fail="exception")
    guard.validate(llm_output, metadata={"sources": [{"id":"s1","for":8,"against":0}, ...]})
"""
import os, sys
sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "..", "service"))
from validator import NolangValidator  # noqa: E402

try:
    from guardrails.validators import Validator, register_validator, PassResult, FailResult
    _HAS_GR = True
except Exception:                       # guardrails не установлен — совместимые заглушки
    _HAS_GR = False

    class Validator:                    # минимальный совместимый базовый класс
        def __init__(self, on_fail=None, **kw): self.on_fail = on_fail

    def register_validator(*a, **k):    # no-op декоратор
        return lambda cls: cls

    class PassResult:
        def __init__(self, **kw): self.outcome = "pass"

    class FailResult:
        def __init__(self, error_message="", fix_value=None, **kw):
            self.outcome = "fail"; self.error_message = error_message; self.fix_value = fix_value


@register_validator(name="arkh/nolang-faithful", data_type="string")
class NolangFaithful(Validator):
    """Валидатор верности: выход LLM допускается, только если ИСТОЧНИКИ его достаточно
    поддерживают (кредальный вердикт nolang ≥ порог). Иначе — Fail с причиной и провенансом."""

    def __init__(self, threshold=0.7, policy="", rule=None, port=8991, on_fail=None, **kw):
        super().__init__(on_fail=on_fail, **kw)
        self._v = NolangValidator(threshold=threshold, policy=policy, rule=rule, port=port)

    def validate(self, value, metadata=None):
        metadata = metadata or {}
        sources = metadata.get("sources", [])
        r = self._v.validate(value, sources)
        if r["decision"] == "emit":
            return PassResult()
        msg = (f"nolang-валидатор: {r['reason']}. вера={r.get('belief')} порог={r['threshold']}. "
               f"провенанс={r.get('provenance')}")
        return FailResult(error_message=msg, fix_value=None)

    # удобный прямой интерфейс (без Guard), возвращает полный результат nolang
    def check(self, llm_output, sources):
        return self._v.validate(llm_output, sources)


HAS_GUARDRAILS = _HAS_GR

# nolang × Guardrails — детерминированный валидатор LLM-выхода

Кастомный [Guardrails AI](https://guardrailsai.com) валидатор, который проверяет выход LLM против
**источников** через nolang-сервис и возвращает Pass/Fail **с провенансом** (почему).

## Чем отличается от обычного guardrail
Обычный валидатор — регекс / ML-классификатор / эмбеддинг: решение вероятностно и непрозрачно.
nolang даёт три свойства **с пробой** (см. `../../КОНТРАКТ.md`, `../../service/contract_test.py`):
- **детерминизм** — один вход даёт один вердикт (12/12);
- **injection-resistance** — веру нельзя назначить прозой, только предъявить свидетелями (§5-bis);
- **аудируемость** — каждый вердикт несёт провенанс (EU AI Act «oversight proportionate to risk»).

## Как работает
`(выход LLM + источники) → свидетели → политика nolang → кредальный вердикт → Pass/Fail`.
Источники передаются в `metadata["sources"]` как `[{"id","for","against","says?","source?"}]`.

## Запуск
1. Поднять nolang-сервис: `NOL_PORT=8991 sbcl --script ../../service/server.lisp`
2. В Guardrails:
   ```python
   from guardrails import Guard
   from nolang_validator import NolangFaithful
   guard = Guard().use(NolangFaithful, threshold=0.7, on_fail="exception")
   guard.validate(llm_output, metadata={"sources": [
       {"id":"s1","for":8,"against":0}, {"id":"s2","for":6,"against":0}]})
   ```
   Без установленного guardrails адаптер работает на совместимом интерфейсе (для теста):
   ```python
   from nolang_validator import NolangFaithful
   NolangFaithful(threshold=0.7).check(llm_output, sources)  # → {decision, verdict, belief, provenance}
   ```

## Границы (пишем честно)
Валидатор проверяет **достаточность поддержки** выхода источниками — не «истину» и не полный AppSec
сервиса. Чистая проба значит «выдержаны ровно эти три свойства на перечисленных входах».

— Часть проекта [nolang](../../). Автор: arkh.

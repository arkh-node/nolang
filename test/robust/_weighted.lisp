;; Робастный порог: взвешенные квантили (Barber, Candès, Ramdas, Tibshirani, AoS 2023).
;; 🔴 Проверяется И польза, И ВРЕД: сторож, показывающий только выигрыш, продаёт лекарство.
(load (merge-pathnames "../../src/theta.lisp" *load-pathname*))
(defun chk (c msg) (format t "~&~a ~a~%" (if c "OK" "FAIL") msg))
(defun sample-false (n center spread seed)
  (let ((st (sb-kernel::seed-random-state seed)))
    (loop repeat n collect (max 0.0 (min 0.999 (+ center (* spread (- (random 1.0 st) 0.5))))))))
(defun leak (th f) (/ (count-if (lambda (b) (>= b th)) f) (float (length f))))
(defun setup (n-same n-other other-center)
  (values (append (sample-false n-same 0.55 0.20 1) (sample-false n-other other-center 0.20 2))
          (append (make-list n-same :initial-element t) (make-list n-other :initial-element nil))
          (sample-false 200 0.55 0.20 9)))

;; 1. при всех весах = 1 совпадает с обычным (иначе это другой метод, а не обобщение)
(let ((c (sample-false 50 0.5 0.3 3)))
  (chk (< (abs (- (theta-conformal c 0.1)
                  (theta-nonexchangeable c (make-list 50 :initial-element 1) 0.1))) 1e-9)
       "веса ≡ 1 дают тот же порог, что обычный conformal — это обобщение, а не подмена"))

;; 2. 🔴 спасает, когда калибровка загрязнена чужой сценой
(multiple-value-bind (calib flags test) (setup 20 180 0.20)
  (let ((plain (leak (theta-conformal calib 0.1) test))
        (weigh (leak (theta-nonexchangeable calib (scene-weights flags 1/16) 0.1) test)))
    (chk (and (> plain 0.9) (< weigh 0.3))
         "калибровка почти вся из чужой сцены: обычный порог бесполезен, взвешенный спасает")))

;; 3. 🔴 И ЧЕСТНО: может УХУДШИТЬ, когда чужие случаи защищали случайно
(multiple-value-bind (calib flags test) (setup 100 100 0.85)
  (let ((plain (leak (theta-conformal calib 0.1) test))
        (weigh (leak (theta-nonexchangeable calib (scene-weights flags 1/16) 0.1) test)))
    (chk (> weigh plain)
         "ГРАНИЦА: где чужие случаи были консервативнее, взвешивание отнимает случайную защиту")))

;; 4. пустая калибровка — по-прежнему отказ, а не догадка
(chk (= 1.0 (theta-nonexchangeable '() '() 0.1))
     "пустая калибровка → 1.0 и во взвешенном варианте: ∅ ↦ ⊥, а не ⊤")

;;; rust-babel.el --- Org babel facilities for rust-mode -*-lexical-binding: t-*-

;; This file is distributed under the terms of both the MIT license and the
;; Apache License (version 2.0).

;;; Code:

(require 'org)
(require 'ob)
(require 'ob-eval)
(require 'ob-ref)

(add-to-list 'org-babel-tangle-lang-exts '("rust" . "rs"))

(defvar rust-babel-buffer-name '((:default . "*rust-babel*")))

(defvar rust-babel-process-name "rust-babel-process")

(defvar rust-babel-compilation-buffer "*rust-babel-compilation-buffer*")

(defvar rust-babel-compilation-failed-p nil)

(defun rust-org-babel-eval (cmdline dir)
  (let* ((err-buff (get-buffer-create rust-babel-compilation-buffer))
        (coding-system-for-read 'binary)
        (process-environment (nconc
	                          (list (format "TERM=%s" "ansi"))
                              process-environment))
        (inhibit-read-only t)
        (params (append '("cargo" "build") (split-string cmdline))))
    (with-current-buffer err-buff
      (erase-buffer)
      (setq-local default-directory dir)
      (rust-compilation-mode))
    (let ((proc (make-process
                 :name rust-babel-process-name
                 :buffer err-buff
                 :command params
                 :filter #'rust-compile-filter
                 :sentinel #'rust-babel-sentinel)))
        (while (eq (process-status proc) 'run)
          (sit-for 0.1)))))

(defun rust-babel-sentinel (proc string)
  (let ((proc-buffer (process-buffer proc))
        (inhibit-read-only t))
    (if (zerop (process-exit-status proc))
        (and
         (setq rust-babel-compilation-failed-p nil)
         (kill-buffer proc-buffer))
      (and
       (setq rust-babel-compilation-failed-p t)
       (pop-to-buffer proc-buffer)))))

(defun rust-babel-generate-project (dir)
  (let* ((default-directory org-babel-temporary-directory))
    (shell-command-to-string (format "cargo new %s --bin --quiet" dir))
    (expand-file-name dir)))

(defun org-babel-execute:rust (body params)
  "Execute a block of Rust code with Babel."
  (let* ((cmdline (cdr (assq :cmdline params)))
         (deps (cdr (assq :deps params)))
         (full-body (org-element-property :value (org-element-at-point)))
         (dir-name (make-temp-file-internal "cargo" 0 "" nil))
         (dir (rust-babel-generate-project dir-name))
         (main (expand-file-name "main.rs" (concat dir "/src"))))
    (while (not (file-exists-p main))
      (setq dir (rust-babel-generate-project dir-name)))
    (let ((default-directory dir))
      (write-region full-body nil main nil 0)
      (rust-org-babel-eval cmdline dir)
      (if (not rust-babel-compilation-failed-p) 
          (let ((result (shell-command-to-string "cargo run --quiet")))
            (org-babel-insert-result result))))))

(provide 'rust-babel)
;;; rust-babel.el ends here




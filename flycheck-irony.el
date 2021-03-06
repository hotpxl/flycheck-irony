;;; flycheck-irony.el --- Flycheck: C/C++ support via Irony  -*- lexical-binding: t; -*-

;; Copyright (C) 2014-2015  Guillaume Papin

;; Author: Guillaume Papin <guillaume.papin@epitech.eu>
;; Keywords: convenience, tools, c
;; Version: 0.1.0-cvs
;; URL: https://github.com/Sarcasm/flycheck-irony/
;; Package-Requires: ((emacs "24.1") (flycheck "0.22") (irony "0.2.0-cvs4"))

;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <http://www.gnu.org/licenses/>.

;;; Commentary:

;; C, C++ and Objective-C support for Flycheck, using Irony Mode.
;;
;; Usage:
;;
;;     (eval-after-load 'flycheck
;;       '(add-hook 'flycheck-mode-hook #'flycheck-irony-setup))

;;; Code:

(require 'irony-diagnostics)

(require 'flycheck)

(eval-when-compile
  (require 'pcase))

(defvar flycheck-irony--ignored-error
  (list "#pragma once in main file")
  "Error messages to ignore.")

(defun flycheck-irony--build-error (checker buffer diagnostic)
  (let ((severity (irony-diagnostics-severity diagnostic)))
    (if (memq severity '(note warning error fatal))
        (flycheck-error-new-at
         (irony-diagnostics-line diagnostic)
         (irony-diagnostics-column diagnostic)
         (pcase severity
           (`note 'info)
           (`warning 'warning)
           ((or `error `fatal) 'error))
         (irony-diagnostics-message diagnostic)
         :checker checker
         :buffer buffer
         :filename (irony-diagnostics-file diagnostic)))))

(defun flycheck-irony--start (checker callback)
  (let ((buffer (current-buffer)))
    (irony-diagnostics-async
     #'(lambda (status &rest args) ;; closure, lexically bound
         (pcase status
           (`error (funcall callback 'errored (car args)))
           (`cancelled (funcall callback 'finished nil))
           (`success
            (let* ((filtered (cl-remove-if
                              (lambda (i)
                                (cl-member
                                 (irony-diagnostics-message i)
                                 flycheck-irony--ignored-error :test 'string=))
                              (car args)))
                   (errors (mapcar #'(lambda (diagnostic)
                                       (flycheck-irony--build-error checker buffer diagnostic))
                                   filtered)))
              (funcall callback 'finished (delq nil errors)))))))))

(defun flycheck-irony--verify (_checker)
  "Verify the Flycheck Irony syntax checker."
  (list
   (flycheck-verification-result-new
    :label "Irony Mode"
    :message (if irony-mode "enabled" "disabled")
    :face (if irony-mode 'success '(bold warning)))

   ;; FIXME: the logic of `irony--locate-server-executable' could be extracted
   ;; into something very useful for this verification
   (let* ((server-path (expand-file-name "bin/irony-server"
                                         irony-server-install-prefix))
          (server-found (file-exists-p server-path)))
     (flycheck-verification-result-new
      :label "irony-server"
      :message (if server-found (format "Found at %s" server-path) "Not found")
      :face (if server-found 'success '(bold error))))))

(flycheck-define-generic-checker 'irony
  "A syntax checker for C, C++ and Objective-C, using Irony Mode."
  :start #'flycheck-irony--start
  :verify #'flycheck-irony--verify
  :modes irony-supported-major-modes
  :error-filter #'identity
  :predicate #'(lambda ()
                 irony-mode))

;;;###autoload
(defun flycheck-irony-setup ()
  "Setup Flycheck Irony.

Add `irony' to `flycheck-checkers'."
  (interactive)
  (add-to-list 'flycheck-checkers 'irony))

(provide 'flycheck-irony)

;;; flycheck-irony.el ends here

;;; luau-ts-mode.el --- tree-sitter support for LUAU  -*- lexical-binding: t; -*-

;; Copyright (C) 2022-2023 Free Software Foundation, Inc.

;; Author     : Ryan C. Scott <ryan@5pmcasual.com>
;; Maintainer : Ryan C. Scott <ryan@5pmcasual.com>
;; Created    : August 2023
;; Keywords   : luau languages tree-sitter

;; This file is part of GNU Emacs.

;; GNU Emacs is free software: you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; GNU Emacs is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with GNU Emacs.  If not, see <https://www.gnu.org/licenses/>.

;;; Commentary:
;;

;;; Code:

(require 'treesit)

(declare-function treesit-parser-create "treesit.c")

(defvar luau-ts-mode--syntax-table
  (let ((table (make-syntax-table)))
    (modify-syntax-entry ?#  "<"  table)
    (modify-syntax-entry ?\n ">"  table)
    (modify-syntax-entry ?&  "."  table)
    (modify-syntax-entry ?*  "."  table)
    (modify-syntax-entry ?\( "."  table)
    (modify-syntax-entry ?\) "."  table)
    (modify-syntax-entry ?\' "\"" table)
    table)
  "Syntax table for `luau-ts-mode'.")

(defvar luau-ts-mode--font-lock-settings
  (treesit-font-lock-rules
   :language 'luau
   :feature 'error
   '((ERROR) @font-lock-comment-face)

   :language 'luau
   :feature 'functioncall
   '((functioncall (var (NAME)) @font-lock-function-name-face))

   :language 'luau
   :feature 'methodcall
   '(method: (NAME) @font-lock-function-name-face)

   :language 'luau
   :feature 'binding
   '((binding (NAME) @font-lock-variable-name-face) (Type) @font-lock-type-face)

   :language 'luau
   :feature 'number
   '((NUMBER) @font-lock-number-face)

   :language 'luau
   :feature 'string
   '((STRING) @font-lock-string-face)

   :language 'luau
   :feature 'comment
   '((comment) @font-lock-comment-face)

   :language 'luau
   :feature 'tableconstructor
   '((tableconstructor ["{" "}"]) @font-lock-property-face)

   :language 'luau
   :feature 'type-name
   '(type_name: (NAME) @font-lock-type-face)

   :language 'luau
   :feature 'keyword
   '((["end" "or" "for" "in" "and" "not" "else" "elseif" "do" "then" "function" "if" "return" "local" "type"]) @font-lock-keyword-face)

   :language 'luau
   :feature 'builtin
   '((["pcall" "coroutine" "require"]) @font-lock-keyword-face)
   )
  "Tree-sitter font-lock settings for `luau-ts-mode'.")

(defvar luau-indent-offset 4)

(defvar luau-ts-mode-indent-rules
  (let ((offset luau-indent-offset))
    `((luau
       ((node-is "}") parent-bol 0)
       ((node-is ")") parent-bol 0)
       ((node-is "]") parent-bol 0)
       ((node-is "\\.") parent-bol ,offset)
       ((node-is "end") parent-bol 0)
       ((node-is "then") parent-bol 0)
       ((node-is "else") parent-bol 0)
       ((node-is "error") prev-sibling 0)

       ((parent-is "if") parent-bol ,offset)
       ((parent-is "loop_for") parent-bol ,offset)
       ((parent-is "loop_while") parent-bol ,offset)
       ((parent-is "loop_repeat") parent-bol ,offset)
       ((parent-is "do_block") parent-bol ,offset)
       ((parent-is "source_file") parent-bol 0)
       ((parent-is "exp") parent-bol ,offset)
       ((parent-is "fieldlist") parent-bol 0)
       ((parent-is "tableconstructor") parent-bol ,offset)
       ((parent-is "TableType") parent-bol ,offset)
       ((parent-is "funcbody") parent-bol ,offset)
       ((parent-is "funcargs") parent-bol ,offset)
       ((parent-is "explist") parent-bol 0)

       (no-node parent-bol ,offset)))))

(defun luau-ts-mode--defun-name (node)
  "Return the defun name of NODE.
Return nil if there is no name or if NODE is not a defun node."
  (pcase (treesit-node-type node)
    ("funcname"
     (treesit-node-text node))
    ("require"
     (treesit-node-text
      (treesit-node-child-by-field-name node "module")))
    ("type_definition"
     (treesit-node-text
      (treesit-node-child-by-field-name node "type_name")))))

(defun luau-ts-mode--node-is-require (node)
  (treesit-node-child-by-field-name node "module"))

;;;###autoload
(define-derived-mode luau-ts-mode prog-mode "LUAU"
  "Major mode for editing LUAU, powered by tree-sitter."
  :group 'luau
  :syntax-table luau-ts-mode--syntax-table

  (when (treesit-ready-p 'luau)
    (treesit-parser-create 'luau)

    ;; Comments.
    (setq-local comment-start "--")
    (setq-local comment-end "")
    (setq-local comment-start-skip (rx "--" (* (syntax whitespace))))

    ;; Indentation.
    (setq-local indent-tabs-mode t)
    (setq-local tab-width luau-indent-offset)

    ;; Font-lock.
    (setq-local treesit-font-lock-settings luau-ts-mode--font-lock-settings)
    (setq-local treesit-font-lock-feature-list
                '((comment)
                  (string type-name)
                  (number keyword functioncall methodcall tableconstructor binding builtin error)))

    (setq-local treesit-simple-indent-rules luau-ts-mode-indent-rules)

    (setq-local treesit-simple-imenu-settings
                `(("Type" "\\`type_definition\\'" nil nil)
                  ("Require" "\\`require\\'" luau-ts-mode--node-is-require nil)
                  ("Function" "\\`funcname\\'" nil nil)))

    (setq-local treesit-defun-name-function #'luau-ts-mode--defun-name)

    (treesit-major-mode-setup)))

;;;###autoload
(add-to-list 'auto-mode-alist '("\\.lua\\'" . luau-ts-mode))

;; Support org-mode, when adding a code block for dot, use this mode
(with-eval-after-load 'org-src
  (defvar org-src-lang-modes)
  (add-to-list 'org-src-lang-modes  '("lua" . luau-ts)))

(provide 'luau-ts-mode)

;;; luau-ts-mode.el ends here

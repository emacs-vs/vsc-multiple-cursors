;;; vsc-multiple-cursors.el --- multiple-cursors integration behave like VSCode  -*- lexical-binding: t; -*-

;; Copyright (C) 2022-2025 Shen, Jen-Chieh

;; Author: Shen, Jen-Chieh <jcs090218@gmail.com>
;; Maintainer: Shen, Jen-Chieh <jcs090218@gmail.com>
;; URL: https://github.com/emacs-vs/vsc-multiple-cursors
;; Version: 0.1.0
;; Package-Requires: ((emacs "27.1") (multiple-cursors "1.4.0"))
;; Keywords: convenience vscode vsc multiple-cursors

;; This file is not part of GNU Emacs.

;; This program is free software: you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program. If not, see <https://www.gnu.org/licenses/>.

;;; Commentary:
;;
;; multiple-cursors integration behave like VSCode.
;;

;;; Code:

(require 'multiple-cursors)

(defgroup vsc-multiple-cursors nil
  "VSCode integration multiple-cursors."
  :prefix "vsc-multiple-cursors-"
  :group 'convenience
  :group 'tools
  :link '(url-link :tag "Repository" "https://github.com/emacs-vs/vsc-multiple-cursors"))

(defcustom vsc-multiple-cursors-cancel-commands
  '()
  "List of command that would cancel multiple cursors."
  :type 'list
  :group 'vsc-multiple-cursors)

(defcustom vsc-multiple-cursors-similarity 20
  "The standard similarity, the lower require more precision."
  :type 'number
  :group 'vsc-multiple-cursors)

;;
;; (@* "Core" )
;;

;;;###autoload
(defun vsc-multiple-cursors-mark-previous-like-this-line ()
  "Smart marking previous line."
  (interactive)
  (let ((before-unmark-cur-cnt (mc/num-cursors))
        (unmark-do (ignore-errors (call-interactively #'mc/unmark-next-like-this))))
    (unless unmark-do
      (unless (> before-unmark-cur-cnt (mc/num-cursors))
        (call-interactively #'mc/mark-previous-like-this)))))

;;;###autoload
(defun vsc-multiple-cursors-mark-next-like-this-line ()
  "Smart marking next line."
  (interactive)
  (let ((before-unmark-cur-cnt (mc/num-cursors))
        (unmark-do (ignore-errors (call-interactively #'mc/unmark-previous-like-this))))
    (unless unmark-do
      (unless (> before-unmark-cur-cnt (mc/num-cursors))
        (call-interactively #'mc/mark-next-like-this)))))

(defun vsc-multiple-cursors--furthest-cursor-before-point ()
  "Goto the furthest cursor before point."
  (when (mc/furthest-cursor-before-point) (goto-char (overlay-end (mc/furthest-cursor-before-point)))))

(defun vsc-multiple-cursors--furthest-cursor-after-point ()
  "Goto furthest cursor after point."
  (when (mc/furthest-cursor-after-point) (goto-char (overlay-end (mc/furthest-cursor-after-point)))))

;;;###autoload
(defun vsc-multiple-cursors-mark-previous-similar-this-line (&optional sdl)
  "Mark previous line similar to this line depends on string distance level (SDL)."
  (interactive)
  (unless sdl (setq sdl vsc-multiple-cursors-similarity))
  (save-excursion
    (let ((cur-line (thing-at-point 'line)) (cur-col (current-column))
          sim-line break)
      (vsc-multiple-cursors--furthest-cursor-before-point)
      (forward-line -1)
      (while (and (not break) (not (= (line-number-at-pos (point)) (line-number-at-pos (point-min)))))
        (setq sim-line (thing-at-point 'line))
        (when (and (< (string-distance sim-line cur-line) sdl)
                   (or (and (not (string= "\n" sim-line)) (not (string= "\n" cur-line)))
                       (and (string= "\n" sim-line) (string= "\n" cur-line))))
          (move-to-column cur-col)
          (mc/create-fake-cursor-at-point)
          (setq break t))
        (forward-line -1))
      (unless break (user-error "[INFO] no previous similar match"))))
  (mc/maybe-multiple-cursors-mode))

;;;###autoload
(defun vsc-multiple-cursors-mark-next-similar-this-line (&optional sdl)
  "Mark next line similar to this line depends on string distance level (SDL)."
  (interactive)
  (unless sdl (setq sdl vsc-multiple-cursors-similarity))
  (save-excursion
    (let ((cur-line (thing-at-point 'line)) (cur-col (current-column))
          sim-line break)
      (vsc-multiple-cursors--furthest-cursor-after-point)
      (forward-line 1)
      (while (and (not break) (not (= (line-number-at-pos (point)) (line-number-at-pos (point-max)))))
        (setq sim-line (thing-at-point 'line))
        (when (and (< (string-distance sim-line cur-line) sdl)
                   (or (and (not (string= "\n" sim-line)) (not (string= "\n" cur-line)))
                       (and (string= "\n" sim-line) (string= "\n" cur-line))))
          (move-to-column cur-col)
          (mc/create-fake-cursor-at-point)
          (setq break t))
        (forward-line 1))
      (unless break (user-error "[INFO] no next similar match"))))
  (mc/maybe-multiple-cursors-mode))

;;;###autoload
(defun vsc-multiple-cursors-inc-similarity ()
  "Increase the string distance level by 1."
  (interactive)
  (setq vsc-multiple-cursors-similarity (1+ vsc-multiple-cursors-similarity))
  (message "[INFO] MC similarity: %s" vsc-multiple-cursors-similarity))

;;;###autoload
(defun vsc-multiple-cursors-dec-similarity ()
  "Decrease the string distance level by 1."
  (interactive)
  (setq vsc-multiple-cursors-similarity (1- vsc-multiple-cursors-similarity))
  (message "[INFO] MC similarity: %s" vsc-multiple-cursors-similarity))

;;
;; (@* "Cancellation" )
;;

(defun vsc-multiple-cursors--cancel-multiple-cursors (&rest _)
  "Cancel the `multiple-cursors' behaviour."
  (when (and (functionp 'mc/num-cursors) (> (mc/num-cursors) 1))
    (mc/keyboard-quit)))

(defun vsc-multiple-cursors--mc/mark-lines (num-lines direction)
  "Override `mc/mark-lines' function."
  (let ((cur-column (current-column)))
    (dotimes (i (if (= num-lines 0) 1 num-lines))
      (mc/save-excursion
       (let ((furthest-cursor (cl-ecase direction
                                (forwards  (mc/furthest-cursor-after-point))
                                (backwards (mc/furthest-cursor-before-point)))))
         (when (overlayp furthest-cursor)
           (goto-char (overlay-get furthest-cursor 'point))
           (when (= num-lines 0)
             (mc/remove-fake-cursor furthest-cursor))))
       (cl-ecase direction
         (forwards (next-logical-line 1 nil))
         (backwards (previous-logical-line 1 nil)))
       (move-to-column cur-column)
       (mc/create-fake-cursor-at-point)))))

(defun vsc-multiple-cursors--enable ()
  "Enable `vsc-multiple-cursors-mode'."
  (dolist (cmd vsc-multiple-cursors-cancel-commands)
    (advice-add cmd :after #'vsc-multiple-cursors--cancel-multiple-cursors))
  (advice-add 'mc/mark-lines :override #'vsc-multiple-cursors--mc/mark-lines))

(defun vsc-multiple-cursors--disable ()
  "Disable `vsc-multiple-cursors-mode'."
  (dolist (cmd vsc-multiple-cursors-cancel-commands)
    (advice-remove cmd #'vsc-multiple-cursors--cancel-multiple-cursors))
  (advice-remove 'mc/mark-lines #'vsc-multiple-cursors--mc/mark-lines))

;;;###autoload
(define-minor-mode vsc-multiple-cursors-mode
  "Minor mode `vsc-multiple-cursors-mode'."
  :global t
  :require 'vsc-multiple-cursors-mode
  :group 'vsc-multiple-cursors
  (if vsc-multiple-cursors-mode (vsc-multiple-cursors--enable) (vsc-multiple-cursors--disable)))

(provide 'vsc-multiple-cursors)
;;; vsc-multiple-cursors.el ends here

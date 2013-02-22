;;; elpad-client.el --- a client for elpad  -*- lexical-binding: t -*-

;; Copyright (C) 2013  Nic Ferrier

;; Author: Nic Ferrier <nferrier@ferrier.me.uk>
;; Keywords: hypermedia
;; Package-Requires: ((websocket "1.0")(web "0.3.1"))
;; Version: 0.0.0.201302211612

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

;; A client for elpad.

;;; Code:

(require 'websocket)
(require 'web)

(defgroup elpad-client nil
  "Emacs client for Elpad text bin."
  :group 'applications)

(defcustom elpad-client-default-host "http://localhost:8007"
  "The default elpad host to send pad requests to."
  :group 'elpad-client
  :type 'string)


(defvar elpad-client/websocket nil
  "Buffer local copy of the websocket we're using.

Must be used to send updates back to the server.")

(defvar elpad-client/uuid nil
  "Buffer local copy of the id of this buffer.")

(make-variable-buffer-local 'elpad-client/websocket)
(make-variable-buffer-local 'elpad-client/uuid)

(defun elpad-client/on-change (beg end len)
  "Fired by elpad-client buffer on-change hook."
  (let ((str (buffer-substring-no-properties beg end)))
    (websocket-send-text
     elpad-client/websocket
     (json-encode
      (list 'change elpad-client/uuid beg end len str)))))

(defun elpad-client/close-buffer ()
  "Hook function to clean up when a client buffer closes."
  (websocket-close elpad-client/websocket))

(defun elpad-client/on-message (socket frame)
  "Handle a message from a websocket.

Messages:

  'yeah - ack from elpad, params buffer-id and the initial text

No other messages currently processed."
  (let* ((fd (websocket-frame-payload frame))
         (data (let ((json-array-type 'list))
                 (json-read-from-string fd))))
    (case (intern (car data))
      (yeah ; subscribe to a buffer
       (destructuring-bind (handle str) (cdr data)
         (let ((buf (get-buffer-create (format "elpad/%s" handle))))
           (with-current-buffer buf
             (setq elpad-client/websocket socket)
             (setq elpad-client/uuid handle)
             (insert str)
             (add-hook
              'after-change-functions 'elpad-client/on-change t t)
             (add-hook
              'kill-buffer-hook 'elpad-client/close-buffer t t))
           ;; Make sure we change there
           (switch-to-buffer-other-window buf)))))))

(defun elpad-client/ws (id ws-host)
  "Connect to ID at WS-HOST.

WS-HOST passed to us by Elpad negotiation."
  (let ((sock (websocket-open
               (format "ws://%s" ws-host)
               :on-message 'elpad-client/on-message)))
    ;; Send the request to the server
    (websocket-send-text sock (json-encode (list 'connect id)))
    sock))

(defun elpad-client/handle-pad (hc header data)
  "HTTP callback from the pad lookup call."
  (let* ((loc (gethash 'location header))
              (server
               (progn
                 (string-match "ws://\\(.*\\);id=\\(.*\\)" loc)
                 (match-string 1 loc)))
              (id (match-string 2 loc)))
    (elpad-client/ws id server)))


(defvar elpad/get-pad-history '()
  "History of `elpad-get' IDs.")

(defun elpad-client-get-pad (url)
  "Get a particular pad by URL from the elpad server."
  (interactive
   (list
    (read-from-minibuffer
     "Elpad url: " (car elpad/get-pad-history)
     nil nil elpad/get-pad-history)))
  (web-http-get
   (lambda (hc header data)
     (when (equal "302" (gethash 'status-code header))
       ;; We should find the header
       (elpad-client/handle-pad hc header data)))
   :url (if (string-match-p "^http://" url) url
            (format "%s%s" elpad-client-default-host url))))

(defun elpad-client-make-pad (buffer start end)
  "Make a new elpad from BUFFER between START and END."
  (interactive
   (list (current-buffer)
         (region-beginning)
         (region-end)))
  (web-http-post
   (lambda (hc header data)
     (when (equal "302" (gethash 'status-code header))
       (elpad-client-get-pad (gethash 'location header))))
   :url (format "%s/pad/" elpad-client-default-host)
   :data `(("username" .  ,user-mail-address)
           ("text" . ,(with-current-buffer
                       buffer
                       (buffer-substring-no-properties start end))))))

(provide 'elpad-client)

;;; elpad-client.el ends here

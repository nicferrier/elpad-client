;;; elpad-client-tests.el - testing for elpad-client

(require 'elpad-client)

(ert-deftest elpad-client/redirect-correct ()
  "Test the redirection correction."
  (should
   (equal
    "http://baseurl/pad/1y2398/"
    (elpad-client/redirect-correct
     "/pad/1y2398/"
     "http://baseurl/pad/thing1/")))
  ;; Test where we have a port
  (should
   (equal
    "http://baseurl:9871/pad/1y2398/"
    (elpad-client/redirect-correct
     "/pad/1y2398/"
     "http://baseurl:9871/pad/thing1/")))
  ;; Test where we don't have a slash on the base
  (should
   (equal
    "http://baseurl/pad/1y2398/"
    (elpad-client/redirect-correct
     "/pad/1y2398/"
     "http://baseurl")))
  ;; Test where we have a good url
  (should
   (equal
    "http://base1/pad/1y2398/"
    (elpad-client/redirect-correct
     "http://base1/pad/1y2398/"
     "http://baseurl/pad/thing1/"))))

;;; elpad-client-tests.el ends here

(require 'company)
(require 'cl)
(require 'cl-lib)
(require 'emacsql)
(require 'emacsql-sqlite)


(defvar company-chapel-db nil)

(defvar company-chapel-db-file nil)

(defun company-chapel-db-init ()
  (when (not company-chapel-db)
    (if (not company-chapel-db-file)
	(error "[ERROR] [COMPANY-CHAPEL] company-chapel-db-file not set"))
    (setf company-chapel-db
	  (emacsql-sqlite company-chapel-db-file))
    (if (not company-chapel-db)
	(error "[ERROR] [COMPANY-CHAPEL] company-chapel error when creating database. Do you have write access to directory?"))
    (ignore-errors 
      (emacsql company-chapel-db [:create-table module ([(name text :primary-key) (modified float)])])
      (emacsql company-chapel-db [:create-table symbol ([(name text) (type integer) (module text)])]))))

(defun company-chapel-cands (arg)
  (if (not company-chapel-db)
      (company-chapel-db-init))
  (if company-chapel-db
      ;;  suggest from all the know symbols 
      (mapcar (lambda (x) (car x))
	      (emacsql company-chapel-db
		       [:select :distinct name :from symbol :where (like name $r1)]
		       ;; "_" is there because it would not work without it
		       ;; emacsql add some character before inserts?
		       (concat "_" arg "%")))
					;)
    '()))



(defun company-chapel-backend (command &optional arg &rest ignored)
  (interactive (list 'interactive))
  (case command
    (interactive
     (company-begin-backend 'company-chapel-backend))
    (prefix (and (eq major-mode 'chapel-mode)
		 (buffer-substring
		  (point)
		  (save-excursion
		    (skip-chars-backward "a-z0-9A-Z.\_")
		    (point)))))
    (candidates (company-chapel-cands arg))))



(defun company-chapel-db-update-symbol (file module line)
  (let* ((lv (split-string line))
	 (l (car lv)))
    (condition-case nil 
	(cond ((string= l "const")
	       (emacsql company-chapel-db [:insert-into symbol :values ([$s1 1 $s2])]
			(replace-regexp-in-string ":" "" (cadr lv))
			module))
	      ((string= l "enum")
	       (emacsql company-chapel-db [:insert-into symbol :values ([$s1 2 $s2])]
			(cadr lv)
				      module))
	      ((string= l "proc")
	       (emacsql company-chapel-db [:insert-into symbol :values ([$s1 3 $s2])]
			(substring (cadr lv) 0 (string-match "(" (cadr lv)))
			module))
	      ((string= l "Record:")
	       (emacsql company-chapel-db [:insert-into symbol :values ([$s1 4 $s2])]
			(cadr lv)
			module)))
      (error nil))))


;; recursively search docs created with chpldoc --text-only				     
(defun company-chapel-db-update (paths)
  (company-chapel-db-init)
  (dolist (path paths)
    (dolist (file (directory-files-recursively path ".*\.txt"))
      (let* ((modu (file-name-base file))
	     (modtime (time-to-seconds (nth 5 (file-attributes file))))
	     (oldmod (caar
		      (emacsql company-chapel-db
			       [:select modified :from module :where (= name $s1)]
			       modu))))
	
	(message "file: %s\tmodule: %s\toldtime: %s\tmodtime %s"
		 file modu oldmod modtime)
	;; file has not been added or it has been modified
	(if (and oldmod (= modtime oldmod))
	    (message "skipping file %s" file))

	(when (or (not oldmod)
		  (/= modtime oldmod))

	  ;; remove symbols from old module 
	  (if oldmod
	      (emacsql company-chapel-db
		       [:delete :from symbol :where (= module $s1)]
		       modu))
	  
	  ;; add module into db
	  (if (not oldmod)
	      (emacsql company-chapel-db
		       [:insert-into module :values [$s1 $s2]] modu modtime))

	  ;; parse doc file line by line
	  (dolist (line (with-temp-buffer 
			  (insert-file-contents file)
			  (split-string (buffer-string) "\n" t)))

	    ;; relevant lines have 3 whitespaces before text, not sure if this is always the case though
	    (let ((v (substring line 3)))
	      (when (> (length v) 0)
		(company-chapel-db-update-symbol file modu v)))))))))

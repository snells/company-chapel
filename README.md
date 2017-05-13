# company-chapel
crude company backend for emacs


Depends on 
*company
*cl
*cl-lib
*emacsql
*emacsql-sqlite


You need to set database file for this to work. 


    (setf company-chapel-db-file "/path/to/company-chapel-sqlite.db")
    (add-to-list 'company-backends 'company-chapel-backend)


To populate the database first generate docs with chpldoc tool.

    chpldoc --text-only Module.chpl -o /path/to/doc 
	
Then you can update your symbol databate in emacs with 

    ;; takes list of paths to recursively search	
    (company-chapel-db-update '("/path/to/doc"))
	
The database stores the doc timestamps and updates only if file has not been added or it has changed  so you can update your symbol database incrementally. 	
	
	
This will only work if you are in chapel-mode.	

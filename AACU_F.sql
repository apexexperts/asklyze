create or replace FUNCTION "AACU_F" (P_Username   In Varchar2, 
                                           P_Password   In Varchar2) 
    Return Boolean 
Is 
    Lcount   Number := 0; 
Begin 
    Select Count (*) 
      Into Lcount 
      From SYS_USERS 
     Where     Upper (USER_NAME) = Upper (P_Username) 
           And ("USER_ACCESS") = 1 
           And Upper (USER_PASSWORD) = Upper (P_Password); 

    If Lcount <> 0 
    Then 
        Return True; 
    Else 
        

        Return False; 
    End If; 
End;
/

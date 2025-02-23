*! version 2.0.3 JMGarrett 05Feb98  STB-43 sg33.1
/* Program to calculate adjusted means for nominal variables in regression */
/* Form:  adjmean y, by(x1 x2) adj(cov1 cov2 ...) options                  */
/* Options required:  by (x1 [x2])   <-- nominal variables only            */
/* Options allowed:  adjust, model, level, graph, bar, graph_options       */

program define adjmean
  version 4.0
  #delimit ;
    local options "BY(string) Adjust(string) Model Graph L2title(string)
      L1title(string) T2title(string) Bar Level(real 95) *" ;
  #delimit cr
  local varlist "req ex min(1) max(1)"
  local if "opt"
  parse "`*'"
  parse "`varlist'", parse(" ")
  preserve
  capture keep `if'
  local yvar="`1'"
  quietly drop if `yvar'==.

* If there are covariates, drop missing values, calculate means
  parse "`adjust'", parse(" ")  
  local numcov=0
  local i=1
  while "`1'"~="" {
    local equal=index("`1'","=")
    if `equal'==0  {
       local cov`i'="`1'"
       local mcov`i'="mean"
       }
    if `equal'~=0  {
       local cov`i'=substr("`1'",1,`equal'-1)
       local mcov`i'=substr("`1'",`equal'+1,length("`1'"))
       }
    quietly drop if `cov`i''==.
    local covlist `covlist' `cov`i''
    local covdisp `covdisp' `1'
    local i=`i'+1
    macro shift
    local numcov=`i'-1
    }
  local i=1
  while `i'<=`numcov' {
    if "`mcov`i''"=="mean" {
      quietly sum `cov`i''
      local mcov`i'=_result(3)
      }
    local i=`i'+1
    }
  keep `yvar' `by' `covlist'

* Read in X variables and create dummy variables
  parse "`by'", parse(" ")
  local xvar1="`1'"
  local vlblx1 : variable label `xvar1'
  quietly drop if `xvar1'==.
  quietly tab `xvar1', gen(X)
  local numcat1=_result(2)
  local i=2
  while `i'<=`numcat1'  {
    local xlist1 `xlist1' X`i'
    local i=`i'+1
    }
  macro shift
  if "`1'"==""  {
    local x2=0
    local numcat=`numcat1'
    }
  if "`1'"~=""  {
    local xlist1 ""
    local i=2
    while `i'<=`numcat1'  {
      rename X`i' X1`i'
      local xlist1 `xlist1' X1`i'
      local i=`i'+1
      }
    local x2=1
    local xvar2="`1'"
    quietly drop if `xvar2'==.
    local vlblx2 : variable label `xvar2'
    quietly tab `xvar2', gen(X2)
    local numcat2=_result(2)
      local i=2
      while `i'<=`numcat2'  {
        local xlist2 `xlist2' X2`i'
        local i=`i'+1
        }
    local numcat=`numcat1'*`numcat2'
  macro shift
  if "`1'"~=""  {
    disp in red "Only two X variables allowed in the by( ) option"
    exit
    }
    
    * create interaction terms
    local i=2
    while `i'<=`numcat1' {
      local j=2
      while `j'<=`numcat2' {
        quietly gen I`i'`j'=X1`i'*X2`j'
        local intlist `intlist' I`i'`j'
        local j=`j'+1
        }
      local i=`i'+1
      }
    }

* Run regression to get parameter estimates
   if "`model'"~="model"  {
     quietly reg `yvar' `xlist1' `xlist2' `intlist' `covlist'
     }
   if "`model'"=="model"  {
     reg `yvar' `xlist1' `xlist2' `intlist' `covlist'
     }
  local varlbly : variable label $S_E_depv
  
* Test for overall association, and interaction if present
  quietly test `xlist1' `xlist2' `intlist'
  local df1=_result(3)
  local df2=_result(5)
  local f=_result(6)
  local probf=fprob(`df1', `df2', `f')
  if `x2'==1  {
    quietly test `intlist'
    local df1i=_result(3)
    local df2i=_result(5)
    local fi=_result(6)
    local probfi=fprob(`df1i', `df2i', `fi')
    }
   
* Collapse to 1 obs. per category, dummy variables, and covariates
  tempvar count
  quietly gen `count'=1
  sort `by'
  #delimit ;
    collapse `count' `yvar' `xlist1' `xlist2' `intlist', by(`by')
      max(. `yvar' `xlist1' `xlist2' `intlist') sum(numobs) ;
  #delimit cr
  quietly replace $S_E_depv=.

* Replace covariates with their means (or specified values)
  local i=1
  while `i'<=`numcov'  {
    quietly gen `cov`i''=`mcov`i''
    local i=`i'+1
    }

* Calculate the adjusted means and confidence intervals
  tempvar linpred
  predict adjmean
  predict se, stdp
  predict `linpred', xb
  local z=invnorm((1-`level'/100)/2)
  gen lower=`linpred'+`z'*se
  gen upper=`linpred'-`z'*se
  
* Print results
  display "   "
  if `numcov'>0  {
    #delimit ;
      display in yel "*" in green "Adjusted" in yel "*" in green
        " Means and `level'% Confidence Intervals" ;
    #delimit cr
    local meantyp="adjmean"
    }
  if `numcov'==0  {
    #delimit ;
      display in yel "*" in green "Unadjusted" in yel "*" in green
        " Means and `level'% Confidence Intervals";
    #delimit cr
    local meantyp="mean"
    quietly gen mean=adjmean
    }
  display "  "
  display in gr "  Outcome:" in yel "      `varlbly' -- $S_E_depv"
  if `x2'==0 {
    display in gr "  Nominal X:" in yel "    `vlblx1' -- `xvar1'"
    }
  if `x2'==1 {
    display in gr "  Nominal X1:" in yel "   `vlblx1' -- `xvar1'"
    display in gr "  Nominal X2:" in yel "   `vlblx2' -- `xvar2'"
    display in gr "  Interaction:" in yel "  `xvar1' * `xvar2'"
    }
  if `numcov'~=0 {display in gr "  Covariates:" in yel "   `covdisp'"}
  if `numcov'==0 {display in gr "  Covariates:" in yel "   (none)"}
  list `by' numobs `meantyp' se lower upper, noob nod
  disp "  "
  disp in green "  Test for difference of `numcat' means:"
  disp "  "
  disp in green "    F(`df1', `df2') =  " in yellow %6.2f `f'
  if `probf'>=.0001 {
    disp in green "    Prob > F   =   " in yellow %7.4f `probf'
    }
  if `probf'<.0001 {
    disp in green "    Prob > F   <   " in yellow "0.0001"
    }
  if `x2'==1  {
    disp "  "
    #delimit ;
      disp in green "  Test for interaction of" in yellow
      " `xvar1' * `xvar2'" in green ":";
    #delimit cr
    disp "  "
    disp in green "    F(`df1i', `df2i') =  " in yellow %6.2f `fi'
    if `probfi'>=.0001 {
      disp in green "    Prob > F   =   " in yellow %7.4f `probfi'
      }
    if `probfi'<.0001 {
      disp in green "    Prob > F   <   " in yellow "0.0001"
      }
    }

* Graph the results, if requested
  if "`graph'"=="graph"  {
    more
    if "`l2title'"=="" {local l2title "`varlbly' -- $S_E_depv"}
    if "`l1title'"=="" & `numcov'==0 {
      if "`bar'"=="" {
        local l1title "Unadjusted Means and `level'% CI" 
        }
      if "`bar'"=="bar" {
        local l1title "Unadjusted Means" 
        }
      }    
    if "`l1title'"=="" & `numcov'>0 {
      if "`bar'"=="" {
        local l1title "Adjusted Means and `level'% CI" 
        }
      if "`bar'"=="bar" {
        local l1title "Adjusted Means"
        }
      }        
    if `x2'==0 {
      if "`bar'"=="" {
      #delimit ;
        graph adjmean lower upper `xvar1', c(.II) s(Oii) `options'
           l2("`l2title'") l1("`l1title'") ;
      #delimit cr
      }
      if "`bar'"=="bar" {
       if "`t2title'"=="" & "`vlblx1'"=="" {local t2title "`xvar1'"}
       if "`t2title'"=="" & "`vlblx1'"~="" {
         local t2title "`vlblx1' -- `xvar1'"
         }
       sort `xvar1'
       #delimit ;
         graph adjmean, by(`xvar1') bar `options' l2("`l2title'")
             l1("`l1title'") t2("`t2title'");
       #delimit cr
       }
      }
    if `x2'==1 {
      local x2val : value label `xvar2'
      sort `xvar2' `xvar1'
      local i=1
      local n=1
      while `n'<=_N  {
        if `xvar2'[`n']~=`xvar2'[`n'-1] {
          local catv`i'=`xvar2'[`n']
          local catv `catv' `catv`i''
          local i=`i'+1
          }
        local n=`n'+1
        }
       if "`x2val'"~="" {
         local i=1 
           while `i'<=`numcat2' {
             local x2lbl`i' : label `x2val' `catv`i''
             local i=`i'+1
             }
          }
       rename adjmean _M
       reshape groups `xvar2' `catv'
       reshape vars _M
       reshape con `xvar1'
       reshape wide
       local i=1
       while `i'<=`numcat2'  {
         if "`x2val'"~="" {label var _M`catv`i'' "`xvar2' = `x2lbl`i''"}
           else           {label var _M`catv`i'' "`xvar2' = `catv`i''"}
         local i=`i'+1
         }
       if "`bar'"=="bar" {
        sort `xvar1'
        graph _M*, by(`xvar1') bar `options' l2("`l2title'") l1("`l1title'")
        }
      if "`bar'"~="bar" {
        graph _M* `xvar1', `options' l2("`l2title'") l1("`l1title'")
        }
      }
    }
end

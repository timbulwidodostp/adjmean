*! version 2.0.4 JMGarrett 14May98  STB-43 sg33.1
/* Program to calculate adjusted probabilities for nominal variables       */
/* Form:  adjprop y, by(x1 x2) adj(cov1 cov2 ...) options                  */
/* Options required:  by (x1 [x2])   <-- nominal variables only            */
/* Options allowed:  adjust, model, level, graph, bar, graph_options       */

program define adjprop
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

* Run logistic regression to get parameter estimates
   if "`model'"~="model"  {
     quietly logistic `yvar' `xlist1' `xlist2' `intlist' `covlist'
     }
   if "`model'"=="model"  {
     logistic `yvar' `xlist1' `xlist2' `intlist' `covlist'
     }
  local varlbly : variable label $S_E_depv
  estimates hold logest
  
* LR test for overall association, and interaction if present
  local l1=-2*_result(2)
  quietly logistic `yvar' `covlist'
  local l2=-2*_result(2)
  local df=`numcat'-1
  local chisq=`l2'-`l1'
  local probchi=chiprob(`df',`chisq')
  if `x2'==1  {
    quietly logistic `yvar' `xlist1' `xlist2' `covlist'
    local l2=-2*_result(2)
    local dfi=(`numcat1'-1)*(`numcat2'-1)
    local chisqi=`l2'-`l1'
    local pchisqi=chiprob(`dfi', `chisqi')
    }
  estimates unhold logest
   
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

* Calculate the adjusted probabilities (risks) and confidence intervals
  tempvar linpred
  predict adjprob
  predict se, stdp
  predict `linpred', xb
  local z=invnorm((1-`level'/100)/2)
  gen upper=1/(1+exp(-`linpred'+`z'*se))
  gen lower=1/(1+exp(-`linpred'-`z'*se))

* Print results
  display "   "
  if `numcov'>0  {
    #delimit ;
      display in yel "*" in green "Adjusted" in yel "*" in green
        " Probabilities and `level'% Confidence Intervals" ;
    #delimit cr
    local probtyp="adjprob"
    }
  if `numcov'==0  {
    #delimit ;
      display in yel "*" in green "Unadjusted" in yel "*" in green
        " Probabilities and `level'% Confidence Intervals";
    #delimit cr
    local probtyp="prob"
    quietly gen prob=adjprob
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
  list `by' numobs `probtyp' se lower upper, noob nod
  disp "  "
  disp in gr "  Likelihood ratio test for difference of `numcat' probabilities:"
  disp "  "
  disp in green "    LR Chi2(`df')    =  " in yellow %6.2f `chisq'
  if `probchi'>=.0001 {
    disp in green "    Prob > Chi2   =   " in yellow %7.4f `probchi'
    }
  if `probchi'<.0001 {
    disp in green "    Prob > Chi2   <   " in yellow "0.0001"
    }
  if `x2'==1  {
    disp "  "
    #delimit ;
      disp in gr "  Likelihood ratio test of interaction for" in yellow 
      " `xvar1' * `xvar2'" in green ":";
    #delimit cr
    disp "  "
    disp in green "    LR Chi2(`dfi')    =  " in yellow %6.2f `chisqi'
    if `pchisqi'>=.0001 {
      disp in green "    Prob > Chi2   =   " in yellow %7.4f `pchisqi'
      }
    if `pchisqi'<.0001 {
      disp in green "    Prob > Chi2   <   " in yellow "0.0001"
      }
    }

* Graph the results, if requested
  if "`graph'"=="graph"  {
    more
    if "`l2title'"=="" {local l2title "`varlbly' -- $S_E_depv"}
    if "`l1title'"=="" & `numcov'==0 {
      if "`bar'"=="" {
        local l1title "Unadjusted Probabilities and `level'% CI"
        }
      if "`bar'"=="bar" { 
        local l1title "Unadjusted Probabilities"
        } 
      }
    if "`l1title'"=="" & `numcov'>0 {
     if "`bar'"=="" {
        local l1title "Adjusted Probabilities and `level'% CI"
        }
      if "`bar'"=="bar" { 
        local l1title "Adjusted Probabilities"
        } 
      }
    if `x2'==0 {
      if "`bar'"=="" {
      #delimit ;
        graph adjprob lower upper `xvar1', c(.II) s(Oii) `options'
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
         graph adjprob, by(`xvar1') bar `options' l2("`l2title'") 
             l1("`l1title'") t2("`t2title'") ;
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
       rename adjprob _M
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
        if "`l1title'"=="" & `numcov'==0 {
          local l1title "Unadjusted Probabilities" 
          }
        if "`l1title'"=="" & `numcov'>0 {
          local l1title "Adjusted Probabilities" 
          }
        sort `xvar1'
        graph _M*, by(`xvar1') bar `options' l2("`l2title'") l1("`l1title'")
        }
      if "`bar'"~="bar" {
        graph _M* `xvar1', `options' l2("`l2title'") l1("`l1title'")
        }
      }
    }
end

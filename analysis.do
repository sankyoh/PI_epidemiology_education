version 16
cls

/**** ***** ***** ***** ***** ***** ***** ***** ***** *****

STEP.1 Data Management 
@Jan 21, 2020 by Yoko OKA

***** ***** ***** ***** ***** ***** ***** ***** ***** ****/

* Read dataset .csv file
import delimited "Dataset.csv", delimiter(",") clear

* Labeling
rename sex sex_txt
gen     sex=0 if sex_txt=="female"
replace sex=1 if sex_txt=="male"
label define sex 0 "female" 1 "male"
label values sex sex
drop sex_txt
order id sex 

label define intv 0 "no PI" 1 "PI"
label values intv intv

label variable sex "sex"
label variable id "id"
label variable intv "PI on notPI"

/**** ***** ***** ***** ***** ***** ***** ***** ***** *****

STEP.2 calculate SATS score 
@Jan 21, 2020 by Yoko OKA

***** ***** ***** ***** ***** ***** ***** ***** ***** ****/

* Reverse score
local reverse_var q04 q05 q07 q08 q11 q13 q15 q16 q18 q21 q24 q25 q26 ///
q28 q30 q33 q34 q35 q36
foreach x of local reverse_var {
	replace sats_pr_`x' = 8 - sats_pr_`x'
	replace sats_po_`x' = 8 - sats_po_`x'
}

* calculate "Interest" score
capture drop interest*
gen interest_pr = (sats_pr_q12 + sats_pr_q20 + sats_pr_q23 + sats_pr_q29)/4
gen interest_po = (sats_po_q12 + sats_po_q20 + sats_po_q23 + sats_po_q29)/4

* calculate "Effort" score
capture drop effort*
gen effort_pr = (sats_pr_q01 + sats_pr_q02 + sats_pr_q14 + sats_pr_q27)/4
gen effort_po = (sats_po_q01 + sats_po_q02 + sats_po_q14 + sats_po_q27)/4

* calculate "Affect" score
capture drop affect*
gen affect_pr =(sats_pr_q03 + sats_pr_q04 + sats_pr_q15 + ///
	sats_pr_q18+ sats_pr_q19 + sats_pr_q28)/6
gen affect_po =(sats_po_q03 + sats_po_q04 + sats_po_q15 + ///
	sats_po_q18+ sats_po_q19 + sats_po_q28)/6

* calculate "Cognitive competence" score
capture drop cognitive_competence*
gen cognitive_competence_pr =(sats_pr_q05 + sats_pr_q11 + sats_pr_q26 + ///
	sats_pr_q31+ sats_pr_q32 + sats_pr_q35)/6
gen cognitive_competence_po =(sats_po_q05 + sats_po_q11 + sats_po_q26 + ///
	sats_po_q31+ sats_po_q32 + sats_po_q35)/6

* calculate "Value" score
capture drop value*
gen value_pr = (sats_pr_q07 + sats_pr_q09 + sats_pr_q10 + sats_pr_q13+ ///
	sats_pr_q16 + sats_pr_q17 + sats_pr_q21 + sats_pr_q25 + sats_pr_q33)/9
gen value_po = (sats_po_q07 + sats_po_q09 + sats_po_q10 + sats_po_q13+ ///
	sats_po_q16 + sats_po_q17 + sats_po_q21 + sats_po_q25 + sats_po_q33)/9

* calculate "Difficulty" score
capture drop difficulty*
gen difficulty_pr = (sats_pr_q06 + sats_pr_q08 + sats_pr_q22 + sats_pr_q24+ ///
	sats_pr_q30 + sats_pr_q34 + sats_pr_q36)/7
gen difficulty_po = (sats_po_q06 + sats_po_q08 + sats_po_q22 + sats_po_q24+ ///
	sats_po_q30 + sats_po_q34 + sats_po_q36)/7
	
* calculate Score difference between pre- and post- 	
local out_vars interest effort affect cognitive_competence value difficulty
foreach x of local out_vars {
	gen `x'_diff = `x'_po - `x'_pr
}

* Rename to short variable-name
foreach x in pr po diff {
	rename interest_`x' int_`x'
	rename effort_`x' eff_`x'
	rename affect_`x' aff_`x'
	rename cognitive_competence_`x' cog_`x'
	rename value_`x' val_`x'
	rename difficulty_`x' dif_`x'
}

save "Dataset.dta", replace

/**** ***** ***** ***** ***** ***** ***** ***** ***** *****

STEP.3 Calculate propensity score and overlap weight 
@Mar 29, 2020 by Toshiharu Mitsuhashi

***** ***** ***** ***** ***** ***** ***** ***** ***** ****/

egen missing = rowmiss(int_diff eff_diff aff_diff cog_diff val_diff dif_diff ///
	intv add_pr* sex int_pr eff_pr aff_pr cog_pr val_pr dif_pr)

* calculate Propensity score
logit intv add_pr* sex int_pr eff_pr aff_pr cog_pr val_pr dif_pr if missing==0
predict pr_ow_0, pr

* calculate Overlap weight
gen    ow_0 = intv*(1-pr_ow_0)+(1-intv)*pr_ow_0 if missing==0
recode pr_ow_0 (.=0)     if missing==0
recode ow_0 (.=0) if missing==0

save "Dataset_ps.dta", replace

/**** ***** ***** ***** ***** ***** ***** ***** ***** *****

STEP.4 Descriptive statistics 
@Mar 29, 2020 by Toshiharu Mitsuhashi

***** ***** ***** ***** ***** ***** ***** ***** ***** ****/	
local out_vars int eff aff cog val dif
capture log close
log using "log_descriptive", replace

* Table 1. Descriptive characteristics of the 141 students.
* Categorical Variable
tab sex intv, col m

* Additional Questions
bysort intv: sum add_pr_q0*, sep(0)

* Pre-SATS Scores
bysort intv: sum *_pr, sep(0)

* Table 2. SATS score change of the 101 students without missing data.
* SATS score change
bysort intv: sum *_diff if missing==0, sep(0)

log close

/**** ***** ***** ***** ***** ***** ***** ***** ***** *****

STEP.5 Balance check of overlap weighted population
@Mar 29, 2020 by Toshiharu Mitsuhashi

***** ***** ***** ***** ***** ***** ***** ***** ***** ****/
capture log close
log using "log_balance_check", replace

* Table 3. Absolute standardized mean differences and variance ratio
capture ssc install covbal 
covbal intv sex add_pr* *_pr         // without weighting
covbal intv sex add_pr* *_pr, wt(ow) // with weighting

* Table 4. Descriptive characteristics of the weighted population.
* Categorical Variable
proportion sex [pw=ow] if intv==1
di "female= " e(b)[1,1]
di "male= "   e(b)[1,2]
proportion sex [pw=ow] if intv==0
di "female= " e(b)[1,1]
di "male= "   e(b)[1,2]

* Additional Questions
forvalues x=1/4{
	mean add_pr_q0`x' [pw=ow] if intv==1
	matrix list e(sd)
	mean add_pr_q0`x' [pw=ow] if intv==0
	matrix list e(sd)
}

* Pre-SATS Score
foreach x of local out_vars {
	mean `x'_pr [pw=ow] if intv==1
	matrix list e(sd)
	mean `x'_pr [pw=ow] if intv==0
	matrix list e(sd)	
}

log close

/**** ***** ***** ***** ***** ***** ***** ***** ***** *****

STEP.6 Calculate estimates of coefficient (Crude analysis)
@Mar 29, 2020 by Toshiharu Mitsuhashi

***** ***** ***** ***** ***** ***** ***** ***** ***** ****/	
capture log close
log using "log_crude", replace

* Table 5. Coef and its 95%CI (Crude analysis)
foreach x of local out_vars {
    reg `x'_diff i.intv if missing==0
}

log close

/**** ***** ***** ***** ***** ***** ***** ***** ***** *****

STEP.7 Calculate estimates of average treatment effect (DR analysis)
@Mar 29, 2020 by Toshiharu Mitsuhashi

***** ***** ***** ***** ***** ***** ***** ***** ***** ****/	
set seed 19271105 // seed number = Akaike Hirotsugu's birth day
capture log close
log using "log_double_robust", replace

foreach x of local out_vars {
	capture drop yhat*
	
	// Potential Outcome, non-PI lecture
	qui:reg `x'_diff sex add_pr* *_pr [pw=ow] if intv==0
	qui:predict yhat0_ipwra  if missing==0
	qui:replace yhat0_ipwra = 6  if yhat0_ipwra > 6
	qui:replace yhat0_ipwra = -6 if yhat0_ipwra < -6

	// Potential Outcome, PI lecture
	qui:reg `x'_diff sex add_pr* *_pr [pw=ow] if intv==1
	qui:predict yhat1_ipwra  if  missing==0
	qui:replace yhat1_ipwra = 6  if yhat0_ipwra > 6
	qui:replace yhat1_ipwra = -6 if yhat0_ipwra < -6

	qui:gen te_`x'=yhat1_ipwra-yhat0_ipwra
	ttest te_`x'==0
}

* Table 5. ATE and its 95%CI (DR analysis)
bootstrap, rep(1000) nodots: mean te_*

log close

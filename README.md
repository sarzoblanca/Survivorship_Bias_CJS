# CJS.SBias

The goal of this R package is to implement Cormack-Jolly-Seber models that correct for survivorship bias, which is often the case when individuals enter into the study at different ages.

In this R package we have implemented three models: Mh, Mah, and Math models, where in all cases the individual heterogeneity is incorporated on survival probabilities. 

The capture-history matrix is that from the study period. For further extensions (considering years previous to the study period), contact with me or check code attached to the paper on Biometrics 2025: Sarzo, B; King, R., and McCrea, R.

**Mh model**

The Mh models corresponds with the heterogeneity model, where survival probability is modelled with an intercept plus the individual random effect and recapture can be modelled age-dependent (or not).

**Mah model**

In this model we consider that survival probabilities are a function of the random effects plus age-dependence. Again, recapture probability can be set as constant or age-dependent too. 

**Math model**

In this last model we extend the dependencies on survival such that we also include time-dependence.

## Data format

Data SHOULD have the form of a matrix of 0's and 1's with the LAST column indicating the INITIAL age of the individuals (age of the individuals at the beginning of the study). Initial ages should start in 1, otherwise it should be changed in the function. The funtion will transform the data to the unique capture histories by intial age directly.

## Functions

There are three functions to implement the above mentioned models (all in the R file: R_Functions):

1) cSB.cjs.Mh -> for Mh model
2) cSB.cjs.Mah -> for Mah model
3) cSB.cjs.Math -> for Math model

Addtionally, within this functions the unique capture-histories for each initial database are computed as well as the age matrices for both survival and recapture probabilities. 

## Imput data

+ Functions will require: 
  * **data**: matrix of 0's and 1's and last two columns corresponding to the number of individuals with each uniqye ch (num) and the initial age of each individual (age).
  * **A**: maxim number of initial ages.
  * **theta**: set of initial values for model parameters.
  * **norule**: number of nodes used for Quadrature, 20-40 are the recommended number but convergence should be checked.
  * **seed.cjs**: seed, for reproducibility.
  * **age.class.surv**: age classes for survival probabilities.
  * **age.class.p**: age classes for recapture probabilities.
 
+ There is available a simulated database: sim_biom_diff_bet.RDS

## Results

+ For each function, the results are saved in a list where is given: (i) summary of the model; (ii) parameters; (iii) unique capture-histories; and (iv) age matrices.

## Examples

+ There us a simulated database available to run these models called: simDB.RDS.

+ To implement the algorithm you should write:

```{r example}
library(CJS.SBias)
## basic example code

## 1. For Mh model
result.Mh <- cSB.cjs.Mh(data=data, A=5,
                       theta=c(rep(0,3)),
                       norule=1,seed.cjs=123)

## 2. For Mah model
result.Mah <- cSB.cjs.Mah(data=data, A=5, age.class.surv=3,
                       age.class.p=1,
                       theta=c(rep(0,5)),
                       norule=1,seed.cjs=123)

## 3. For Math model
result.Math <- cSB.cjs.Math(db=db, A=5, age.class.surv=3,
                            age.class.p=1,
                            theta=c(rep(0,16)),
                            norule=1,seed.cjs=123)
```

## Installation from GitHub

```{r example}
install.packages("remotes")

remotes::install_github("sarzoblanca/Survivorship_Bias_CJS")                           
```


################
## Mh MODEL
###############
## Data: matrix with ch's and last column indicating IA

cSB.cjs.Mh <- function(data, A,
                       theta, norule,
                       seed.cjs) {
  
  set.seed(seed.cjs) # for reproducibility
  
  ## Warnings
  old_warn <- getOption("warn")
  options(warn = -1)
  
  ## Parameters
  n.occasions <- dim(data)[2] - 1 # last column indicates IA
  
  ##########################################
  ## 1. Function to create the unique ch's
  ##########################################
  uniq.CH <- function(x) {
    
    ## Create capture-histories
    pasty.CH <- function(x) {
      k <- ncol(x-1)  # Number of columns (T)
      n <- nrow(x-1)  # Number of rows
      out <- array(dim = n)
      
      for (i in 1:n) {
        data <- (x[i, ] > 0) * 1  # Convert to 1 when x>0
        out[i] <- paste(data[1:k], collapse = "")
      }
      return(out)
    }
    
    ## BY initial age
    ## The last column indicates INITIAL AGE
    INage_col <- ncol(x)
    
    ## Split the data.frame by INITIAL AGE
    list_by_INage <- split(x, x[, INage_col])
    
    ## Create a list for the results
    uniq_CH_byAGE <- list()
    
    ## Apply
    for (age in names(list_by_INage)) {
      subset <- list_by_INage[[age]]
      
      ## Remove initial age
      subset_NOage <- subset[, -INage_col]
      CH_strings <- pasty.CH(subset_NOage)
      
      ## Create data.frame with the initial data,
      ## the chains, and initial age
      temp_df <- data.frame(subset_NOage)  # Original matrix (data)
      temp_df$CH_strings <- CH_strings     # Chains: ch's
      
      ## How may different ch's
      uniq.ch <- as.data.frame(table(CH_strings))
      names(uniq.ch) <- c("CH_strings", "Num")
      uniq.ch$CH_strings <- as.character(uniq.ch$CH_strings)
      
      ## Join the results
      temp <- left_join(temp_df, uniq.ch, by="CH_strings")
      CH.uniq <- temp[!duplicated(temp$CH_strings), ]
      CH.uniq$age <- age
      
      uniq_CH_byAGE[[age]] <- as.data.frame(CH.uniq)
    }
    
    ## Transform to data.frame
    uniq_CH_byAGE <- do.call(rbind, uniq_CH_byAGE) %>%
      as.data.frame(.)
    
    rownames(uniq_CH_byAGE) <- NULL
    uniq_CH_byAGE$age <- as.numeric(uniq_CH_byAGE$age)
    
    return(uniq_CH_byAGE)
  }
  
  print("Executing unique CH's...")
  ## Execute function
  uniq.DB <- uniq.CH(data)
  
  print(uniq.DB %>% head(.))
  
  ############################################
  ## Second function: corrected Mh CJS model
  ############################################
  
  ## Data: only the matrix with 0's and 1's
  x <- uniq.DB
  CH <- x[,c(1:n.occasions)]
  
  ## More parameters
  nind <- dim(CH)[1]
  n.occasions <- dim(CH)[2]
  
  ## Function to indicate ringing time (f.db)
  ## and last time observed (l.db)
  fun.first <- function(x) min(which(x!=0))
  fun.last <- function(x) max(which(x!=0))
  
  f.db <- apply(CH,1,fun.first)
  l.db <- apply(CH,1,fun.last)
  
  ## Gaussian-Hermite Quadrature
  # norule <- norule
  rule.nd <- gaussHermiteData(norule)
  epsilon <- rule.nd$x
  
  ## Vector of initial ages
  vec.init <- x$age
  
  ## Range of initial ages
  uniq.IA <- sort(unique(vec.init))
  
  ## Positions by initial age
  pos.by.IA <- sapply(uniq.IA,
                      function(age) which(vec.init == age))
  
  ## Freq of the unique ch's
  CH.uniq.num <- x$Num
  
  #######################################
  ### SB corrected CJS Mah MODEL
  #######################################
  likfn.QUAD.Mh <- function(theta,CH,
                            nind,f.db,l.db,n.occasions,
                            norule,rule.nd,
                            CH.uniq.num, A,
                            vec.init, epsilon,
                            pos.by.IA, abs.surv){
    
    p <- c()
    phi <- array(0, dim=c(nind, n.occasions, norule))
    abs.phi <- array(0, dim=c(nind, norule))
    
    lik <- loglik <- array(0, dim=c(nind,norule))
    part1 <- array(0, dim=c(nind,norule))
    exp.loglik <- array(1, dim=c(nind, norule))
    chi <- array(1, dim=c(nind, norule))
    lik2.QUAD <- loglik3.QUAD <- array(0,nind)
    lik.fun <- array(0,nind)
    
    ## STARTING FUNCTION...
    ## FIRST QUADRATURE FOR condtional REs DISTRIBUTION
    GA.b <- array(0, dim=c(nind,norule))
    cond.RE <- array(0, dim=c(nrow=nind))
    log.GA <- c()
    alter <- c()
    log.eval.pdf0 <- c()
    
    sigma <- exp(theta[1])
    
    ## LIKELIHOOD
    p <- 1/(1+exp(-theta[3]))
    
    for (a in 2:A){
      for (i in pos.by.IA[[a]]){
        for (k in 1:norule){
          abs.phi[i,k] <- log((1/(1+exp(-epsilon[k]-(theta[3]))))^(a-1))
          
          log.eval.pdf0[k] <- dnorm(epsilon[k],0,sigma, log=T)
          GA.b[i,k] <- (log.eval.pdf0[k]+abs.phi[i,k]) + epsilon[k]^2
        }
        cond.RE[i] <- sum(exp(GA.b[i,])*rule.nd$w)
      }
    }
    
    for (i in 1:nind){
      for (k in 1:norule){
        for (t in f.db[i]:(n.occasions-1)){
          phi[i,t,k] <- 1/(1+exp(-epsilon[k]-theta[2]))
        }
        if (f.db[i]!=l.db[i]){
          part1[i,k] <- sum(log(phi[i,f.db[i]:(l.db[i]-1),k]))
          lik[i,k] <- lik[i,k] + part1[i,k]
          # }
          for (j in f.db[i]:(l.db[i]-1)) {
            lik[i,k] <- lik[i,k] + (data[i,j+1]*log(p)) +
              (1-data[i,j+1])*log(1-p)
          }
        }
        
        # To calculate the probability of not being observed
        # again in the study:
        if (l.db[i] < n.occasions){
          for (t in (n.occasions-1):l.db[i]){
            chi[i,k] <- (1-phi[i,t,k]) + (phi[i,t,k]*(1-p)*chi[i,k])
          }
        }
        lik[i,k] <- lik[i,k] + log(chi[i,k])
        
        ## Continue
        if (vec.init[i]==1){
          loglik[i,k] <- lik[i,k] + log.eval.pdf0[k]
        }
        else {
          alter <- (exp(log.eval.pdf0[k])*exp(abs.phi[i,k]))*(1/cond.RE[i])
          loglik[i,k] <- lik[i,k] + (log(alter))
        }
        
        loglik[i,k] <- loglik[i,k] + epsilon[k]^2
        exp.loglik[i,k] <- exp(loglik[i,k])
      }
      
      lik2.QUAD[i] <- sum(exp.loglik[i,]*rule.nd$w)
      loglik3.QUAD[i] <- CH.uniq.num[i]*log(lik2.QUAD[i])
    }
    ## Sum among ages AND indiv
    lik.fun <- -sum(loglik3.QUAD, na.rm=T)
    cat(theta, lik.fun, "\n")
    lik.fun
  }
  
  print("Executing SB corrected CJS Mh model...")
  
  ## Execute function
  model.cjs <- nlm(p=theta,
                   f=likfn.QUAD.Mh,
                   CH=CH,
                   f.db=f.db,l.db=l.db,
                   nind=nind,
                   n.occasions=n.occasions,
                   norule=norule,
                   rule.nd=rule.nd,
                   CH.uniq.num=CH.uniq.num,
                   A=A, vec.init=vec.init,
                   epsilon=epsilon,
                   pos.by.IA=pos.by.IA,
                   abs.surv=abs.surv,
                   hessian = T)
  
  print(model.cjs)
  
  ## Back transform sigma and recapture probabilities
  sigma <- exp(model.cjs$estimate[1])
  recapture <- c(1/(1+exp(-model.cjs$estimate[3])))
  alpha <- c(model.cjs$estimate[2])
  
  param <- list(sigma=sigma, recapture=recapture,
                alpha=alpha)
  
  ## Results
  results.SB.Mh <- list(model=model.cjs,
                        param=param,
                        uniq.CH=uniq.CH)
  
  return(results.SB.Mh)
  
  ## Warnings
  options(warn = old_warn)
}

# ######################################
# ## Example to execute main function
# ######################################
# cjs.Mh <- cSB.cjs.Mh(data=data, A=5,
#                        theta=c(rep(0,3)),
#                        norule=10,seed.cjs=123)data <- simDB


############################
## Mah model
############################
## Data: matrix with ch's and last column indicating IA
library(dplyr)
library(plyr)
library("fastGHQuad")

cSB.cjs.Mah <- function(data, A,
                        age.class.surv,
                        age.class.p, theta,
                        norule, seed.cjs) {
  
  set.seed(seed.cjs) # for reproducibility
  
  ## Warnings
  old_warn <- getOption("warn")
  options(warn = -1)
  
  ## Parameters
  n.occasions <- dim(data)[2] - 1 # last column indicates IA
  
  ##########################################
  ## 1. Function to create the unique ch's
  ##########################################
  uniq.CH <- function(x) {
    
    ## Create capture-histories
    pasty.CH <- function(x) {
      k <- ncol(x-1)  # Number of columns (T)
      n <- nrow(x-1)  # Number of rows
      out <- array(dim = n)
      
      for (i in 1:n) {
        data <- (x[i, ] > 0) * 1  # Convert to 1 when x>0
        out[i] <- paste(data[1:k], collapse = "")
      }
      return(out)
    }
    
    ## BY initial age
    ## The last column indicates INITIAL AGE
    INage_col <- ncol(x)
    
    ## Split the data.frame by INITIAL AGE
    list_by_INage <- split(x, x[, INage_col])
    
    ## Create a list for the results
    uniq_CH_byAGE <- list()
    
    ## Apply
    for (age in names(list_by_INage)) {
      subset <- list_by_INage[[age]]
      
      ## Remove initial age
      subset_NOage <- subset[, -INage_col]
      CH_strings <- pasty.CH(subset_NOage)
      
      ## Create data.frame with the initial data,
      ## the chains, and initial age
      temp_df <- data.frame(subset_NOage)  # Original matrix (data)
      temp_df$CH_strings <- CH_strings     # Chains: ch's
      
      ## How may different ch's
      uniq.ch <- as.data.frame(table(CH_strings))
      names(uniq.ch) <- c("CH_strings", "Num")
      uniq.ch$CH_strings <- as.character(uniq.ch$CH_strings)
      
      ## Join the results
      temp <- left_join(temp_df, uniq.ch, by="CH_strings")
      CH.uniq <- temp[!duplicated(temp$CH_strings), ]
      CH.uniq$age <- age
      
      uniq_CH_byAGE[[age]] <- as.data.frame(CH.uniq)
    }
    
    ## Transform to data.frame
    uniq_CH_byAGE <- do.call(rbind, uniq_CH_byAGE) %>%
      as.data.frame(.)
    
    rownames(uniq_CH_byAGE) <- NULL
    uniq_CH_byAGE$age <- as.numeric(uniq_CH_byAGE$age)
    
    return(uniq_CH_byAGE)
  }
  
  print("Executing unique CH's...")
  ## Execute function
  uniq.DB <- uniq.CH(data)
  
  print(uniq.DB %>% head(.))
  
  #############################################################
  ## 2. Function to calculate age-matrices
  ## Regarding age classes for survival and recapture probs
  #############################################################
  matrix.age <- function(uniq.DB, A,
                         n.occasions,
                         age.class.surv,
                         age.class.p){
    
    ## Data with the unique ch's
    x <- uniq.DB
    
    ## Vector of initial ages
    vec.init <- x$age
    
    ## Data
    x <- x[,c(1:n.occasions)]
    
    ## Range of initial ages
    uniq.IA <- sort(unique(vec.init))
    
    ## Positions by initial age
    pos.by.IA <- sapply(uniq.IA,
                        function(age) which(vec.init == age))
    
    ## Indicate ringing time and last time observed
    fun.first <- function(x) min(which(x!=0))
    fun.last <- function(x) max(which((x!=0)))
    
    f.db <- apply(x,1,fun.first)
    l.db <- apply(x,1,fun.last)
    
    nind <- dim(x)[1]
    
    ## Create initial age vectors for each parameter
    A.vec.surv <- function(A, n.occasions, age.class.surv) {
      age_list <- list()
      
      for (a in 1:A) {
        if(a>=age.class.surv){
          age_vector <- age.class.surv
        } else{age_vector <- c(a:min(age.class.surv,
                                     a + n.occasions - 1))}
        
        if (length(age_vector) < n.occasions) {
          age_vector <- c(age_vector,
                          rep(age.class.surv,
                              n.occasions - length(age_vector)))
        }
        age_list[[a]] <- age_vector
      }
      return(age_list)
    }
    
    ## Recapture
    A.vec.rec <- function(A, n.occasions, age.class.p) {
      age_list <- list()
      
      for (a in 1:A) {
        if(a>=age.class.p){
          age_vector <- age.class.p
        } else{age_vector <- c(a:min(age.class.p, a + n.occasions - 1))}
        
        if (length(age_vector) < n.occasions) {
          age_vector <- c(age_vector, rep(age.class.p, n.occasions - length(age_vector)))
        }
        age_list[[a]] <- age_vector
      }
      return(age_list)
    }
    
    
    ## Execute function
    vec.age.surv <- A.vec.surv(A, n.occasions, age.class.surv)
    vec.age.p <- A.vec.rec(A, n.occasions, age.class.p)
    
    ## Create age.class matrices
    x.class.surv <- matrix(NA, ncol=n.occasions, nrow=nind)
    x.class.p <- matrix(NA, ncol=n.occasions, nrow=nind)
    
    f.inverse <- (n.occasions+1)-f.db
    
    for (a in 1:A){
      for (i in pos.by.IA[[a]]){
        x.class.surv[i,f.db[i]:dim(x.class.surv)[2]] <- vec.age.surv[[a]][1:f.inverse[i]]
        x.class.p[i,f.db[i]:dim(x.class.p)[2]] <- vec.age.p[[a]][1:f.inverse[i]]
      }
    }
    return(list(matrix.age.surv=x.class.surv,
                matrix.age.p=x.class.p))
  }
  
  print("Executing age matrices...")
  ## Execute function
  res <- matrix.age(uniq.DB,
                    A, n.occasions,
                    age.class.surv,
                    age.class.p)
  
  matrix.age.surv <- res$matrix.age.surv
  matrix.age.p <- res$matrix.age.p
  
  print(matrix.age.surv %>% head(.))
  print(matrix.age.p %>% head(.))
  
  ############################################
  ## Third function: corrected Mah CJS model
  ############################################
  
  ## Data: only the matrix with 0's and 1's
  x <- uniq.DB
  CH <- x[,c(1:n.occasions)]
  
  ## More parameters
  nind <- dim(CH)[1]
  n.occasions <- dim(CH)[2]
  
  ## Function to indicate ringing time (f.db)
  ## and last time observed (l.db)
  fun.first <- function(x) min(which(x!=0))
  fun.last <- function(x) max(which(x!=0))
  
  f.db <- apply(CH,1,fun.first)
  l.db <- apply(CH,1,fun.last)
  
  ## Gaussian-Hermite Quadrature
  # norule <- norule
  rule.nd <- gaussHermiteData(norule)
  epsilon <- rule.nd$x
  
  ## Vector of initial ages
  vec.init <- x$age
  
  ######################################
  ## FUNCTION FOR ABSOLUTE SURV. PROBS.
  ######################################
  fun_surv <- function(A, age.class.surv) {
    a2 <- list()
    
    for (a in 2:A) {
      a2[[a]] <- 2:a
      
      if (length(a2[[a]]) > age.class.surv) {
        a2[[a]][(age.class.surv+1):length(a2[[a]])] <- age.class.surv + 1
      }
    }
    
    return(a2)
  }
  
  ## Execute function
  abs.surv <- fun_surv(A, age.class.surv)
  
  ## Range of initial ages
  uniq.IA <- sort(unique(vec.init))
  
  ## Positions by initial age
  pos.by.IA <- sapply(uniq.IA,
                      function(age) which(vec.init == age))
  
  ## Freq of the unique ch's
  CH.uniq.num <- x$Num
  
  #######################################
  ### SB corrected CJS Mah MODEL
  #######################################
  likfn.QUAD.Mah <- function(theta,CH,
                             nind,f.db,l.db,n.occasions,
                             norule,rule.nd,
                             CH.uniq.num, A,
                             age.class.p,
                             vec.init, epsilon,
                             pos.by.IA, matrix.age.surv,
                             age.class.surv,
                             matrix.age.p,abs.surv){
    
    p <- array(0, dim=age.class.p)
    phi <- array(0, dim=c(nind, age.class.surv,norule))
    abs.phi <- array(0, dim=c(nind, norule))
    
    lik <- loglik <- array(0, dim=c(nind,norule))
    part1 <- array(0, dim=c(nind,norule))
    exp.loglik <- array(1, dim=c(nind, norule))
    chi <- array(1, dim=c(nind, norule))
    lik2.QUAD <- loglik3.QUAD <- array(0,nind)
    lik.fun <- array(0,nind)
    
    ## STARTING FUNCTION...
    ## FIRST QUADRATURE FOR conditional REs DISTRIBUTION
    GA.b <- array(0, dim=c(nind,norule))
    cond.RE <- array(0, dim=c(nrow=nind))
    alter <- c()
    log.eval.pdf0 <- c()
    
    sigma <- exp(theta[1])
    
    for (a in 2:A){
      for (i in pos.by.IA[[a]]){
        for (k in 1:norule){
          abs.phi[i,k] <- log(prod((1/(1+exp(-epsilon[k]-(theta[abs.surv[[a]]]))))))
          
          log.eval.pdf0[k] <- dnorm(epsilon[k],0,sigma, log=T)
          GA.b[i,k] <- (log.eval.pdf0[k]+ abs.phi[i,k]) +
            epsilon[k]^2
        }
        cond.RE[i] <- sum(exp(GA.b[i,])*rule.nd$w)
      }
    }
    
    ## LIKELIHOOD
    ## Recapture
    for (i in 1:nind){
      for (t in f.db[i]:(n.occasions-1)){
        p[(matrix.age.p[i,t+1])] <- 1/(1+exp(-theta[matrix.age.p[i,t+1]+(age.class.surv+1)]))
      }
    }
    
    for (i in 1:nind){
      for (k in 1:norule){
        for (t in f.db[i]:(n.occasions-1)){
          phi[i,matrix.age.surv[i,t],k] <- 1/(1+exp(-epsilon[k]-theta[matrix.age.surv[i,t]+1]))
        }
        
        if (f.db[i]!=l.db[i]){
          part1[i,k] <- sum(log(phi[i,matrix.age.surv[i,f.db[i]:(l.db[i]-1)],k]))
          lik[i,k] <- lik[i,k] + part1[i,k]
          
          for (j in f.db[i]:(l.db[i]-1)) {
            lik[i,k] <- lik[i,k] +
              (CH[i,j+1]*log(p[(matrix.age.p[i,j+1])])) +
              (1-CH[i,j+1])*log(1-p[(matrix.age.p[i,j+1])])
          }
        }
        
        # To calculate the probability of not being observed
        # again in the study:
        if (l.db[i] < n.occasions){
          for (t in (n.occasions-1):l.db[i]){
            chi[i,k] <- (1-phi[i,matrix.age.surv[i,t],k]) +
              (phi[i,matrix.age.surv[i,t],k]*(1-p[(matrix.age.p[i,t+1])])*chi[i,k])
          }
        }
        lik[i,k] <- lik[i,k] + log(chi[i,k])
        
        ## REs distribution for initial ages
        
        if (vec.init[i]==1){
          loglik[i,k] <- lik[i,k] + log.eval.pdf0[k]
        }
        else {
          alter <- (exp(log.eval.pdf0[k])*exp(abs.phi[i,k]))*(1/cond.RE[i])
          loglik[i,k] <- lik[i,k] + (log(alter))
        }
        
        loglik[i,k] <- loglik[i,k] + epsilon[k]^2
        exp.loglik[i,k] <- exp(loglik[i,k])
      }
      
      lik2.QUAD[i] <- sum(exp.loglik[i,]*rule.nd$w)
      loglik3.QUAD[i] <- CH.uniq.num[i]*log(lik2.QUAD[i])
    }
    
    ## Sum among ages AND indiv
    lik.fun <- -sum(loglik3.QUAD, na.rm=T)
    cat(theta, lik.fun, "\n")
    return(lik.fun)
  }
  print("Executing SB corrected CJS Mah model...")
  
  ## Execute function
  model.cjs <- nlm(p=theta,
                   f=likfn.QUAD.Mah,
                   CH=CH,
                   f.db=f.db,l.db=l.db,
                   nind=nind,
                   n.occasions=n.occasions,
                   norule=norule,
                   rule.nd=rule.nd,
                   CH.uniq.num=CH.uniq.num,
                   A=A, vec.init=vec.init,
                   epsilon=epsilon,
                   pos.by.IA=pos.by.IA,
                   age.class.surv=age.class.surv,
                   age.class.p=age.class.p,
                   matrix.age.surv=matrix.age.surv,
                   matrix.age.p=matrix.age.p,
                   abs.surv=abs.surv,
                   hessian = T)
  
  print(model.cjs)
  
  ## Back transform sigma and recapture probabilities
  sigma <- exp(model.cjs$estimate[1])
  recapture <- c(1/(1+exp(-model.cjs$estimate[(age.class.surv+1):length(theta)])))
  alphas <- c(model.cjs$estimate[2:(age.class.surv+2)])
  
  param <- list(sigma=sigma, recapture=recapture,
                alphas=alphas)
  
  ## Results
  results.SB.Mah <- list(model=model.cjs,
                         param=param,
                         uniq.DB=uniq.DB,
                         matrix.age.surv=matrix.age.surv,
                         matrix.age.p=matrix.age.p)
  
  return(results.SB.Mah)
  
  ## Warnings
  options(warn = old_warn)
}

# #######################################
# ## Example to execute main function
# #######################################
# cjs.Mah <- cSB.cjs.Mah(data=data, A=5, age.class.surv=3,
#                              age.class.p=1,
#                        theta=c(rep(0,5)),
#                              norule=1,seed.cjs=123)


###############################
## Math model
###############################

cSB.cjs.Math <- function(db, A,
                         age.class.surv,
                         age.class.p, theta,
                         norule, seed.cjs) {
  
  set.seed(seed.cjs) # for reproducibility
  
  ## Warnings
  old_warn <- getOption("warn")
  options(warn = -1)
  
  ## Parameters
  n.occasions <- dim(db)[2] - 1 # last column indicates IA
  
  ##########################################
  ## 1. Function to create the unique ch's
  ##########################################
  uniq.CH <- function(x) {
    
    ## Create capture-histories
    pasty.CH <- function(x) {
      k <- ncol(x-1)  # Number of columns (T)
      n <- nrow(x-1)  # Number of rows
      out <- array(dim = n)
      
      for (i in 1:n) {
        ch <- (x[i, ] > 0) * 1  # Convert to 1 when x>0
        out[i] <- paste(ch[1:k], collapse = "")
      }
      return(out)
    }
    
    ## BY initial age
    ## The last column indicates INITIAL AGE
    INage_col <- ncol(x)
    
    ## Split the data.frame by INITIAL AGE
    list_by_INage <- split(x, x[, INage_col])
    
    ## Create a list for the results
    uniq_CH_byAGE <- list()
    
    ## Apply
    for (age in names(list_by_INage)) {
      subset <- list_by_INage[[age]]
      
      ## Remove initial age
      subset_NOage <- subset[, -INage_col]
      CH_strings <- pasty.CH(subset_NOage)
      
      ## Create data.frame with the initial data,
      ## the chains, and initial age
      temp_df <- data.frame(subset_NOage)  # Original matrix (db)
      temp_df$CH_strings <- CH_strings     # Chains: ch's
      
      ## How may different ch's
      uniq.ch <- as.data.frame(table(CH_strings))
      names(uniq.ch) <- c("CH_strings", "Num")
      uniq.ch$CH_strings <- as.character(uniq.ch$CH_strings)
      
      ## Join the results
      temp <- left_join(temp_df, uniq.ch, by="CH_strings")
      CH.uniq <- temp[!duplicated(temp$CH_strings), ]
      CH.uniq$age <- age
      
      uniq_CH_byAGE[[age]] <- as.data.frame(CH.uniq)
    }
    
    ## Transform to data.frame
    uniq_CH_byAGE <- do.call(rbind, uniq_CH_byAGE) %>%
      as.data.frame(.)
    
    rownames(uniq_CH_byAGE) <- NULL
    uniq_CH_byAGE$age <- as.numeric(uniq_CH_byAGE$age)
    
    return(uniq_CH_byAGE)
  }
  
  print("Executing unique CH's...")
  ## Execute function
  uniq.DB <- uniq.CH(db)
  
  print(uniq.DB %>% head(.))
  
  #############################################################
  ## 2. Function to calculate age-matrices
  ## Regarding age classes for survival and recapture probs
  #############################################################
  matrix.age <- function(uniq.DB, A,
                         n.occasions,
                         age.class.surv,
                         age.class.p){
    
    ## Data with the unique ch's
    x <- uniq.DB
    
    ## Vector of initial ages
    vec.init <- x$age
    
    ## Data
    x <- x[,c(1:n.occasions)]
    
    ## Range of initial ages
    uniq.IA <- sort(unique(vec.init))
    
    ## Positions by initial age
    pos.by.IA <- sapply(uniq.IA,
                        function(age) which(vec.init == age))
    
    ## Indicate ringing time and last time observed
    fun.first <- function(x) min(which(x!=0))
    fun.last <- function(x) max(which((x!=0)))
    
    f.db <- apply(x,1,fun.first)
    l.db <- apply(x,1,fun.last)
    
    nind <- dim(x)[1]
    
    ## Create initial age vectors for each parameter
    A.vec.surv <- function(A, n.occasions, age.class.surv) {
      age_list <- list()
      
      for (a in 1:A) {
        if(a>=age.class.surv){
          age_vector <- age.class.surv
        } else{age_vector <- c(a:min(age.class.surv,
                                     a + n.occasions - 1))}
        
        if (length(age_vector) < n.occasions) {
          age_vector <- c(age_vector,
                          rep(age.class.surv,
                              n.occasions - length(age_vector)))
        }
        age_list[[a]] <- age_vector
      }
      return(age_list)
    }
    
    ## Recapture
    A.vec.rec <- function(A, n.occasions, age.class.p) {
      age_list <- list()
      
      for (a in 1:A) {
        if(a>=age.class.p){
          age_vector <- age.class.p
        } else{age_vector <- c(a:min(age.class.p, a + n.occasions - 1))}
        
        if (length(age_vector) < n.occasions) {
          age_vector <- c(age_vector, rep(age.class.p, n.occasions - length(age_vector)))
        }
        age_list[[a]] <- age_vector
      }
      return(age_list)
    }
    
    
    ## Execute function
    vec.age.surv <- A.vec.surv(A, n.occasions, age.class.surv)
    vec.age.p <- A.vec.rec(A, n.occasions, age.class.p)
    
    ## Create age.class matrices
    x.class.surv <- matrix(NA, ncol=n.occasions, nrow=nind)
    x.class.p <- matrix(NA, ncol=n.occasions, nrow=nind)
    
    f.inverse <- (n.occasions+1)-f.db
    
    for (a in 1:A){
      for (i in pos.by.IA[[a]]){
        x.class.surv[i,f.db[i]:dim(x.class.surv)[2]] <- vec.age.surv[[a]][1:f.inverse[i]]
        x.class.p[i,f.db[i]:dim(x.class.p)[2]] <- vec.age.p[[a]][1:f.inverse[i]]
      }
    }
    return(list(matrix.age.surv=x.class.surv,
                matrix.age.p=x.class.p))
  }
  
  print("Executing age matrices...")
  ## Execute function
  res <- matrix.age(uniq.DB,
                    A, n.occasions,
                    age.class.surv,
                    age.class.p)
  
  matrix.age.surv <- res$matrix.age.surv
  matrix.age.p <- res$matrix.age.p
  
  print(matrix.age.surv %>% head(.))
  print(matrix.age.p %>% head(.))
  
  ############################################
  ## Third function: corrected Math CJS model
  ############################################
  
  ## Data: only the matrix with 0's and 1's
  x <- uniq.DB
  CH <- x[,c(1:n.occasions)]
  
  ## More parameters
  nind <- dim(CH)[1]
  n.occasions <- dim(CH)[2]
  
  ## Function to indicate ringing time (f.db)
  ## and last time observed (l.db)
  fun.first <- function(x) min(which(x!=0))
  fun.last <- function(x) max(which(x!=0))
  
  f.db <- apply(CH,1,fun.first)
  l.db <- apply(CH,1,fun.last)
  
  ## Gaussian-Hermite Quadrature
  # norule <- norule
  rule.nd <- gaussHermiteData(norule)
  epsilon <- rule.nd$x
  
  ## Vector of initial ages
  vec.init <- x$age
  
  ## Range of initial ages
  uniq.IA <- sort(unique(vec.init))
  
  ## Positions by initial age
  pos.by.IA <- sapply(uniq.IA,
                      function(age) which(vec.init == age))
  
  ## Freq of the unique ch's
  CH.uniq.num <- x$Num
  
  #######################################
  ## FUNCTION FOR 'GHOST' BETA PARAM.
  ## ARITHMETIC MEAN
  #######################################
  ## pos.betas is the position where the betas start (in theta)
  ## These are the number of beta's we need
  
  pos.betas <- length(c("sigma", rep("rec",age.class.p))) +
    age.class.surv + 1
  
  f.inverse <- (n.occasions+1)-f.db
  mat.betas <- list()
  
  for (a in 2:A){
    for (i in pos.by.IA[[a]]){
      if (f.inverse[i]>(pos.betas-1)){
        mat.betas[[i]] <- c(pos.betas:f.inverse[i])}
    }
  }
  
  ## How many mean.betas?
  num.mean <- c()
  for (a in 2:A){
    for (i in pos.by.IA[[a]]){
      if (f.db[i]<a){
        num.mean[i] <- a-f.db[i]
      }
    }
  }
  
  ######################################
  ## FUNCTION FOR ABSOLUTE SURV. PROBS.
  ######################################
  fun_surv <- function(A, age.class.surv) {
    ## For survival
    a2 <- list()
    for (a in 2:A){
      if (a<(age.class.surv+2)){
        a2[[a]] <- c(1:(a-1))
      }
      if (a>(age.class.surv+1)){
        a2[[a]] <- c(1:(age.class.surv-1), rep(age.class.surv,
                                               a-age.class.surv))
      }
    }
    return(a2)
  }
  
  ## Execute function
  abs.surv <- fun_surv(A, age.class.surv)
  
  #######################################
  ### SB corrected CJS Mah MODEL
  #######################################
  likfn.QUAD.Math <- function(theta,CH,
                              nind,f.db,l.db,n.occasions,
                              norule,rule.nd,
                              CH.uniq.num, A,
                              age.class.p,
                              vec.init, epsilon,
                              pos.by.IA, matrix.age.surv,
                              age.class.surv,
                              matrix.age.p,abs.surv){
    
    p <- array(0, dim=age.class.p)
    phi <- array(0, dim=c(nind,n.occasions-1,age.class.surv,norule))
    abs.phi <- array(0, dim=c(nind, norule))
    
    lik <- loglik <- array(0, dim=c(nind,norule))
    part1 <- array(0, dim=c(nind,norule,n.occasions-1))
    part2 <- array(0, dim=c(nind,norule))
    exp.loglik <- array(1, dim=c(nind, norule))
    chi <- array(1, dim=c(nind, norule))
    lik2.QUAD <- loglik3.QUAD <- array(0,nind)
    lik.fun <- array(0,nind)
    
    ## STARTING FUNCTION...
    ## FIRST QUADRATURE FOR conditional REs DISTRIBUTION
    GA.b <- array(0, dim=c(nind,norule))
    cond.RE <- array(0, dim=c(nrow=nind))
    alter <- c()
    log.eval.pdf0 <- c()
    temp.betas <- list()
    
    ## If using 'ghost' betas as arithmetic mean
    pos.betas <- length(c("sigma", rep("rec",age.class.p))) +
      age.class.surv + 1
    
    alg.mean.betas <- list()
    beta.mean <- mean(theta[pos.betas:(pos.betas+
                                         (n.occasions-2))])
    ##############################################################
    sigma <- exp(theta[1])
    
    ## To avoid lack of identifiability in last two parameters
    ## We need to set alpha1 <- 0
    theta[(age.class.p+2)] <- 0
    
    ###########################################################
    ## Consider the unknown betas being the
    ## arithmetic mean of all of them
    
    for (a in 2:A){
      for (i in pos.by.IA[[a]]){
        ## If ghost betas = arithmetic mean:
        if(!is.na(num.mean[i])){
          alg.mean.betas[[i]] <- rep(beta.mean,num.mean[i])
          temp.betas[[i]] <- c(theta[mat.betas[[i]]],
                               alg.mean.betas[[i]])
        } else {temp.betas[[i]] <- c(theta[mat.betas[[i]]])}
        for (k in 1:norule){
          abs.phi[i,k] <- log(prod((1/(1+exp(-epsilon[k]-(theta[abs.surv[[a]]+age.class.p+1])- temp.betas[[i]])))))
          
          ## Conditional REs distrib
          log.eval.pdf0[k] <- dnorm(epsilon[k],0,sigma, log=T)
          GA.b[i,k] <- (log.eval.pdf0[k]+abs.phi[i,k]) + epsilon[k]^2
        }
        # print(i)
        cond.RE[i] <- sum(exp(GA.b[i,])*rule.nd$w)
      }
    }
    
    ## LIKELIHOOD
    ## Recapture
    for (i in 1:nind){
      for (t in f.db[i]:(n.occasions-1)){
        p[(matrix.age.p[i,t+1])] <- 1/(1+exp(-theta[matrix.age.p[i,t+1]+1]))
      }
    }
    
    for (i in 1:nind){
      for (k in 1:norule){
        for (t in f.db[i]:(n.occasions-1)){
          phi[i,t,matrix.age.surv[i,t],k] <- 1/(1+exp(-epsilon[k]-theta[matrix.age.surv[i,t]+age.class.p+1]-theta[t+(pos.betas-1)]))
        }
        if (f.db[i]!=l.db[i]){
          for (j in f.db[i]:(l.db[i]-1)){
            part1[i,k,j] <- log(phi[i,j,matrix.age.surv[i,j],k])
          }
          part2[i,k] <- sum(part1[i,k,f.db[i]:(l.db[i]-1)])
          lik[i,k] <- lik[i,k] + part2[i,k]
          
          for (j in f.db[i]:(l.db[i]-1)) {
            lik[i,k] <- lik[i,k] + (CH[i,j+1]*log(p[(matrix.age.p[i,j+1])])) + (1-CH[i,j+1])*log(1-p[(matrix.age.p[i,j+1])])
          }
        }
        
        # To calculate the probability of not being observed
        # again in the study:
        if (l.db[i] < n.occasions){
          for (t in (n.occasions-1):l.db[i]){
            chi[i,k] <- (1-phi[i,t,matrix.age.surv[i,t],k]) + phi[i,t,matrix.age.surv[i,t],k]*(1-p[(matrix.age.p[i,t+1])])*chi[i,k]
          }
        }
        lik[i,k] <- lik[i,k] + log(chi[i,k])
        
        ## Continue
        ## If different ages are considered
        ## Initial age (birth) - log.eval.pdf0
        if (vec.init[i]==1){
          loglik[i,k] <- lik[i,k] + log.eval.pdf0[k]
        }
        else {
          alter <- (exp(log.eval.pdf0[k])*exp(abs.phi[i,k]))*(1/cond.RE[i])
          loglik[i,k] <- lik[i,k] + (log(alter))
        }
        
        loglik[i,k] <- loglik[i,k] + epsilon[k]^2
        exp.loglik[i,k] <- exp(loglik[i,k])
      }
      
      lik2.QUAD[i] <- sum(exp.loglik[i,]*rule.nd$w)
      loglik3.QUAD[i] <- CH.uniq.num[i]*log(lik2.QUAD[i])
    }
    ## Sum among ages AND indiv
    lik.fun <- -sum(loglik3.QUAD, na.rm=T)
    cat(theta, lik.fun, "\n")
    lik.fun
  }
  
  
  print("Executing SB corrected CJS Math model...")
  
  ## Execute function
  model.cjs <- nlm(p=theta,
                   f=likfn.QUAD.Math,
                   CH=CH,
                   f.db=f.db,l.db=l.db,
                   nind=nind,
                   n.occasions=n.occasions,
                   norule=norule,
                   rule.nd=rule.nd,
                   CH.uniq.num=CH.uniq.num,
                   A=A, vec.init=vec.init,
                   epsilon=epsilon,
                   pos.by.IA=pos.by.IA,
                   age.class.surv=age.class.surv,
                   age.class.p=age.class.p,
                   matrix.age.surv=matrix.age.surv,
                   matrix.age.p=matrix.age.p,
                   abs.surv=abs.surv,
                   hessian = T)
  
  print(model.cjs)
  
  ## Back transform sigma and recapture probabilities
  sigma <- exp(model.cjs$estimate[1])
  recapture <- c(1/(1+exp(-model.cjs$estimate[(age.class.surv+3):length(theta)])))
  alphas <- c(model.cjs$estimate[2:(age.class.surv+2)])
  
  param <- list(sigma=sigma, recapture=recapture,
                alphas=alphas)
  
  ## Results
  results.SB.Mah <- list(model=model.cjs,
                         param=param,
                         uniq.CH=uniq.CH,
                         matrix.age.surv=matrix.age.surv,
                         matrix.age.p=matrix.age.p)
  
  return(results.SB.Mah)
  
  ## Warnings
  options(warn = old_warn)
}

# ##########################################
# ## Example to execute main function
# ##########################################
# cjs.Mah <- cSB.cjs.Math(db=db, A=5, age.class.surv=3,
#                        age.class.p=1,
#                        theta=c(rep(0,16)),
#                        norule=1,seed.cjs=123)





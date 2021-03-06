interpolateLatentTrajectory <- function(params=list(lambda0,lambda1,alpha,beta,q1,q2), 
                                        events, zt, initial.state=NULL, termination.time=NULL, termination.state=NULL,
                                        default.inactive = 2){
  # input params:
  #       events: length N (not include 0)
  #       zt: inferred latent state, 1 or 2 , length N
  #       initial.state: 1 or 2
  # output  z.hat: states of Markov process
  #         x.hat: time of each transition of Markov process
  
  interevent <- diff(c(0,events))
  N <- length(interevent)
  inactive_state <- setdiff(unique(zt),c(1))
  
  if(params$alpha < 0){
    params$alpha <- abs(params$alpha)
  }
  if(length(unique(zt))==1){
    ## no change at all
    z.hat <- rep(unique(zt),2)
    x.hat <- tail(events,1)
    
    ## termination state
    
    if(!is.null(termination.time)){
      if(is.null(termination.state)){
        if(unique(zt)==1){
          ## check whether state can change between last event and termination time, if change
          ## helper variables
          A.m <- cumsum(exp(params$beta*events)) #length = n; A=alpha/beta*A.m
          frequent.par <- params$q2-params$q1+params$lambda0-params$lambda1
          
          if(frequent.par<=0){
            x.hat[1] <- tail(events,1) # TODO
            z.hat[2] <- default.inactive
            x.hat[2] <- termination.time
            z.hat[3] <- default.inactive
          }else{
            if(is.finite(A.m[N])){
              l_0 <- params$alpha/params$beta*A.m[N]*exp(-params$beta*events[N])
              l_Delta <- frequent.par*(termination.time-events[N]) + params$alpha/params$beta*A.m[N]*exp(-params$beta*termination.time)
              ## debugging here
              # no error here
              ##
              if(l_0>l_Delta){
                x.hat[1] <- tail(events,1) 
                z.hat[2] <- default.inactive
                x.hat[2] <- termination.time
                z.hat[3] <- default.inactive
              }
            }
          }
        }
      }else{
        x.hat[1] <- tail(events,1) # TODO
        z.hat[2] <- termination.state
        x.hat[2] <- termination.time
        z.hat[3] <- termination.state
      }
    }
    
    ## initial state
    if(!is.null(initial.state)){
      if(initial.state!=unique(zt)){
        ## check whether state can change between 0 and first event time, if change
        # initial.delta <- events[1]/2 #TODO
        # x.hat <- c(initial.delta,x.hat)
        # z.hat <- c(initial.state,z.hat)
        
        ## if not change
      }
    }
  }else{
    z.hat <- rep(NA,sum(diff(zt)!=0)+1)
    x.hat <- rep(NA,sum(diff(zt)!=0)+1)
    
    ## helper variables
    A.m <- cumsum(exp(params$beta*events)) #length = n; A=alpha/beta*A.m
    frequent.par <- params$q2-params$q1+params$lambda0-params$lambda1
    
    z.hat[1] <- zt[1]
    #x.hat[1] <- 0
    temp.count <- 1
    for(l in 2:N){
      if(zt[l]==1 & zt[l-1]==inactive_state){ #inactive change to active
        if(frequent.par<=0){
          x.hat[temp.count] <- events[l-1]
        }else{
          temp.delta <- 1/params$beta*log(frequent.par/(A.m[l-1]*params$alpha))
          if(events[l-1]+temp.delta>=0){
            x.hat[temp.count] <- events[l-1]
          }else if(events[l]+temp.delta<=0){
            x.hat[temp.count] <- events[l]
          }else{
            x.hat[temp.count] <- -temp.delta
          }
        }
        z.hat[temp.count+1] <- 1
        temp.count <- temp.count + 1
      }
      
      if(zt[l]==inactive_state & zt[l-1]==1){ #active change to inactive
        if(frequent.par<=0){
          x.hat[temp.count] <- events[l-1]
        }else{
          l_0 <- params$alpha/params$beta*A.m[l-1]*exp(-params$beta*events[l-1])
          l_Delta <- frequent.par*(events[l]-events[l-1]) + params$alpha/params$beta*A.m[l-1]*exp(-params$beta*events[l])
          ## debug here
          #print(l)
          #print(l_0)
          #print(l_Delta)
          #NaN's here for both these quantities..
          # can we get around this with an is.finite outside it all?
          ##
          if(is.finite(A.m[l])){ # added this if and corresponding else below
            if(l_0>l_Delta){
              x.hat[temp.count] <- events[l-1]
            }else{
              x.hat[temp.count] <- events[l]
            }
          }else{
            # not sure what exactly should be in this else, try just get it running for now
            x.hat[temp.count] <- events[l-1] # just a guess
          }

        }
        
        z.hat[temp.count+1] <- inactive_state
        temp.count <- temp.count + 1
      }
    }
    
    ## termination
    if(is.null(termination.time)){
      x.hat[temp.count] <- tail(events,1)
      z.hat[temp.count+1] <- z.hat[temp.count]
    }else{
      if(is.null(termination.state)){
        if(z.hat[temp.count]==1){
          ## check whether state can change between last event and termination time, if change
          if(frequent.par<=0){
            x.hat[temp.count] <- tail(events,1)
            z.hat[temp.count+1] <- inactive_state
            x.hat[temp.count+1] <- termination.time
            z.hat[temp.count+2] <- inactive_state
          }else{
            l_0 <- params$alpha/params$beta*A.m[N]*exp(-params$beta*events[N])
            l_Delta <- frequent.par*(termination.time-events[N]) + params$alpha/params$beta*A.m[N]*exp(-params$beta*termination.time)
            if(is.finite(A.m[N])){
              if(l_0>l_Delta){
                x.hat[temp.count] <- tail(events,1)
                z.hat[temp.count+1] <- inactive_state
                x.hat[temp.count+1] <- termination.time
                z.hat[temp.count+2] <- inactive_state
              }else{
                x.hat[temp.count] <- termination.time
                z.hat[temp.count+1] <- z.hat[temp.count]
              }
            }else{
              x.hat[temp.count] <- termination.time
              z.hat[temp.count+1] <- z.hat[temp.count]
            }
          }
        }else{
          x.hat[temp.count] <- termination.time
          z.hat[temp.count+1] <- z.hat[temp.count]
        }
      }else{
        x.hat[temp.count] <- termination.time
        z.hat[temp.count+1] <- termination.state
      }
    }
    
    ## initial
    if(!is.null(initial.state)){
      if(initial.state!=zt[1]){
        ## check whether state can change between 0 and first event time, if change
        # initial.delta <- events[1]/2 #TODO
        # x.hat <- c(initial.delta, x.hat)
        # z.hat <- c(initial.state, z.hat)
        
        ## if not change
      }
    }
  }
  return(list(x.hat=x.hat,z.hat=z.hat))
}


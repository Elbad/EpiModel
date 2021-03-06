context("New DCM models")


test_that("New DCMs Example 1", {

  ## SI function
  intSI <- function(t, t0, parms) {
    with(as.list(c(t0, parms)), {

      ## Dynamic Calculations
      # Population size
      num <- s.num + i.num

      # Intervention start time: if time > start,
      #   then multiply lambda by relative hazard
      if (t < start.time) {
        lambda <- inf.prob*act.rate*i.num/num
      } else {
        lambda <- (inf.prob*act.rate*i.num/num) * rel.haz
      }

      ## Flows
      si.flow <- lambda * s.num

      ## Differential Equations
      dS <- -lambda*s.num
      dI <- lambda*s.num

      ## Output
      list(c(dS, dI, si.flow),
           num = num)
    })
  }


  init <- init.dcm(s.num = 999, i.num = 1, si.flow = 0)
  control <- control.dcm(nsteps = 250, dt = 1, new.mod = intSI, verbose = FALSE)
  param1 <- param.dcm(inf.prob = 0.5, act.rate = 0.1,
                      start.time = seq(100, 200, 100), rel.haz = 1)
  param05 <- param.dcm(inf.prob = 0.5, act.rate = 0.1,
                       start.time = seq(100, 200, 100), rel.haz = 0.5)
  mod1 <- dcm(param1, init, control)
  mod2 <- dcm(param05, init, control)

  expect_is(mod1, "dcm")
  expect_is(mod2, "dcm")
})


test_that("New DCMs Example 2", {

  ## Q Mod Function
  Qmod <- function(t, t0, parms) {
    with(as.list(c(t0, parms)), {

      ## Dynamic Calculations ##

      # Popsize and prevalence
      h.num <- sh.num + ih.num
      l.num <- sl.num + il.num
      num <- h.num + l.num
      prev <- (ih.num + il.num) / num

      # Contact rates for high specified as a function of
      #   mean and low rates
      c.high <- (c.mean*num - c.low*l.num) / h.num

      # Mixing matrix calculations based on variable Q statistic
      g.hh <- ((c.high*h.num) + (Q*c.low*l.num)) /
        ((c.high*h.num) + (c.low*l.num))
      g.lh <- 1 - g.hh
      g.hl <- (1 - g.hh) * ((c.high*h.num) / (c.low*l.num))
      g.ll <- 1 - g.hl

      # Probability that contact is infected based on mixing probabilities
      p.high <- (g.hh*ih.num/h.num) + (g.lh*il.num/l.num)
      p.low <- (g.ll*il.num/l.num) + (g.hl*ih.num/h.num)

      # Force of infection for high and low groups
      lambda.high <- rho * c.high * p.high
      lambda.low <- rho * c.low * p.low


      ## Differential Equations ##
      dS.high <- -lambda.high*sh.num + nu*ih.num
      dI.high <- lambda.high*sh.num - nu*ih.num

      dS.low <- -lambda.low*sl.num + nu*il.num
      dI.low <- lambda.low*sl.num - nu*il.num


      ## Output ##
      list(c(dS.high, dI.high,
             dS.low, dI.low),
           num = num,
           prev = prev)
    })
  }


  param <- param.dcm(c.mean = 2,
                     c.low = 1.4,
                     rho = 0.75,
                     nu = 6,
                     Q = c(-0.45, 0.5, 1))
  init <- init.dcm(sh.num = 2e7*0.02,
                   ih.num = 1,
                   sl.num = 2e7*0.98,
                   il.num = 1)
  control <- control.dcm(nsteps = 6, dt = 0.02, new.mod = Qmod, verbose = FALSE)

  mod <- dcm(param, init, control)
  expect_is(mod, "dcm")

})


test_that("DCM inital conditions ordering correct", {

  SEIR <- function(t, t0, parms) {
    with(as.list(c(t0, parms)), {
      num <- s.num + e.num + i.num + r.num
      lambda <- inf.prob * act.rate * i.num/num
      se.flow = lambda * s.num
      ei.flow = sx.rate * e.num
      ir.flow = rec.rate * i.num
      dS <- -lambda * s.num
      dE <- lambda * s.num - sx.rate * e.num
      dI <- sx.rate * e.num - rec.rate * i.num
      dR <- rec.rate * i.num
      list(c(dS, dE, dI, dR, se.flow, ei.flow, ir.flow),
           num = num)
    })
  }

  init <- init.dcm(s.num = 980, e.num = 10, i.num = 10, r.num = 0,
                   se.flow = 0, ei.flow = 0, ir.flow = 0)
  expect_identical(names(init), c("s.num", "e.num", "i.num", "r.num",
                                  "se.flow", "ei.flow", "ir.flow"))

  param <- param.dcm(inf.prob = 0.2, act.rate = 0.5, sx.rate = 0.1, rec.rate = 0.05)
  control <- control.dcm(nsteps = 10, dt = 1, new.mod = SEIR)

  mod <- dcm(param, init, control)
  expect_is(mod, "dcm")
  expect_identical(names(as.data.frame(mod))[3], "e.num")
})


test_that("Non-sensitivity parameter vector", {

  ## SI function
  intSI <- function(t, t0, parms) {
    with(as.list(c(t0, parms)), {

      ## Dynamic Calculations
      # Population size
      num <- s.num + i.num

      if (t < start.time) {
        lambda <- inf.prob[1]*act.rate*i.num/num
      } else {
        lambda <- inf.prob[2]*act.rate*i.num/num
      }

      ## Flows
      si.flow <- lambda * s.num

      ## Differential Equations
      dS <- -si.flow
      dI <- si.flow

      ## Output
      list(c(dS, dI, si.flow),
           num = num)
    })
  }

  param <- param.dcm(inf.prob = c(0.5, 0.05), act.rate = 0.1, start.time = 100)
  init <- init.dcm(s.num = 999, i.num = 1, si.flow = 0)
  control <- control.dcm(nsteps = 250, new.mod = intSI, sens.param = FALSE)
  mod <- dcm(param, init, control)
  expect_is(mod, "dcm")
  expect_true(any(!is.na(as.data.frame(mod))))
})

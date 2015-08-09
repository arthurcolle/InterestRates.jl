
# Tests for module InterestRates

using Base.Test
using BusinessDays
using InterestRates

vert_x = [ 11, 15, 19, 23 ]
vert_y = [ 0.10, 0.15, 0.20, 0.19 ]

dt_curve = Date(2015,08,03)

BusinessDays.initcache()

curve_b252_ec_lin = InterestRates.IRCurve("dummy-linear", InterestRates.BDays252(BrazilBanking()), 
	InterestRates.ExponentialCompounding(), InterestRates.Linear(), dt_curve,
	vert_x, vert_y)
 
@test getcurvename(curve_b252_ec_lin) == "dummy-linear"
@test getcurvedate(curve_b252_ec_lin) == dt_curve

maturity_2_days = advancebdays(BrazilBanking(), dt_curve, vert_x[1] + 2)
yrs = (vert_x[1] + 2) / 252.0
zero_rate_2_days = 0.125
disc_2_days = 1.0 / ( (1.0 + zero_rate_2_days)^yrs)
@test_approx_eq zero_rate_2_days zero_rate(curve_b252_ec_lin, maturity_2_days) # Linear interpolation

println("zero_rate for linear interpolation")
@time zero_rate(curve_b252_ec_lin, maturity_2_days)

@test_approx_eq disc_2_days discountfactor(curve_b252_ec_lin, maturity_2_days)
@test_approx_eq zero_rate(curve_b252_ec_lin, advancebdays(BrazilBanking(), dt_curve, 11)) 0.10
@test_throws ErrorException zero_rate(curve_b252_ec_lin, advancebdays(BrazilBanking(), dt_curve, -4)) # maturity before curve date
@test_approx_eq zero_rate(curve_b252_ec_lin, advancebdays(BrazilBanking(), dt_curve, 11-4)) 0.05 # extrapolate before first vertice
@test_approx_eq zero_rate(curve_b252_ec_lin, advancebdays(BrazilBanking(), dt_curve, 23+4)) 0.18 # extrapolate after last vertice

curve_ac360_cont_ff = InterestRates.IRCurve("dummy-cont-flatforward", InterestRates.Actual360(),
	InterestRates.ContinuousCompounding(), InterestRates.FlatForward(), dt_curve,
	vert_x, vert_y)

@test_approx_eq zero_rate(curve_ac360_cont_ff, dt_curve + Dates.Day(11)) 0.1
@test_approx_eq zero_rate(curve_ac360_cont_ff, dt_curve + Dates.Day(15)) 0.15
@test_approx_eq zero_rate(curve_ac360_cont_ff, dt_curve + Dates.Day(19)) 0.20
@test_approx_eq zero_rate(curve_ac360_cont_ff, dt_curve + Dates.Day(23)) 0.19
@test zero_rate(curve_ac360_cont_ff, dt_curve + Dates.Day(16)) > 0.15
@test zero_rate(curve_ac360_cont_ff, dt_curve + Dates.Day(17)) < 0.20
@test_approx_eq forward_rate(curve_ac360_cont_ff, dt_curve + Dates.Day(11), dt_curve + Dates.Day(15)) 0.2875 # forward_rate calculation on vertices
@test_approx_eq forward_rate(curve_ac360_cont_ff, dt_curve + Dates.Day(11), dt_curve + Dates.Day(13)) 0.2875 # forward_rate calculation on interpolated maturity
@test_approx_eq ERF(curve_ac360_cont_ff, dt_curve + Dates.Day(13)) 1.00466361875533 # ffwd interp on ERF

println("ERF for FlatForward interpolation")
@time ERF(curve_ac360_cont_ff, dt_curve + Dates.Day(13))

@test_approx_eq zero_rate(curve_ac360_cont_ff, dt_curve + Dates.Day(13)) 0.128846153846152 # ffwd interp as zero_rate

println("zero_rate for FlatForward interpolation")
@time zero_rate(curve_ac360_cont_ff, dt_curve + Dates.Day(13))

@test_approx_eq ERF(curve_ac360_cont_ff, dt_curve + Dates.Day(19), dt_curve + Dates.Day(23)) 1.00158458746737
@test_approx_eq forward_rate(curve_ac360_cont_ff, dt_curve + Dates.Day(19), dt_curve + Dates.Day(23)) 0.1425000000000040
@test_approx_eq zero_rate(curve_ac360_cont_ff, dt_curve + Dates.Day(30)) 0.1789166666666680 # ffwd extrap after last vertice
@test_approx_eq forward_rate(curve_ac360_cont_ff, dt_curve + Dates.Day(19), dt_curve + Dates.Day(23)) forward_rate(curve_ac360_cont_ff, dt_curve + Dates.Day(50), dt_curve + Dates.Day(51))
@test_approx_eq forward_rate(curve_ac360_cont_ff, dt_curve + Dates.Day(19), dt_curve + Dates.Day(23)) forward_rate(curve_ac360_cont_ff, dt_curve + Dates.Day(50), dt_curve + Dates.Day(100))

@test_approx_eq forward_rate(curve_ac360_cont_ff, dt_curve + Dates.Day(11), dt_curve + Dates.Day(15)) 0.2875
@test_approx_eq zero_rate(curve_ac360_cont_ff, dt_curve + Dates.Day(9)) 0.05833333333333 # ffwd extrap before first vertice

@test discountfactor(curve_ac360_cont_ff, dt_curve) == 1
@test isnan(ERF_to_rate(curve_ac360_cont_ff, 1.0, 0.0))

# Null curve tests
n_curve = InterestRates.NullIRCurve()
@test n_curve == InterestRates.NullIRCurve() # Should be singleton
@test ERF(n_curve, Date(2000,1,1)) == 1.0
@test ER(n_curve, Date(2000,1,1)) == 0.0
@test discountfactor(n_curve, Date(2000,1,1)) == 1.0
@test getcurvename(n_curve) == "NullCurve"
@test isnullcurve(n_curve) == true
@test isnullcurve(curve_ac360_cont_ff) == false
@test forward_rate(n_curve, Date(2000,1,1), Date(2000,1,2)) == 0.0
@test zero_rate(n_curve, Date(2000,1,1)) == 0.0
@test zero_rate(n_curve, [Date(2000,1,1), Date(2000,1,2)]) == [ 0.0, 0.0 ]

# Tests for vector functions
dt_curve = Date(2015, 08, 07)
curve_ac365_simple_linear = InterestRates.IRCurve("dummy-simple-linear", InterestRates.Actual365(),
	InterestRates.SimpleCompounding(), InterestRates.Linear(), dt_curve,
	vert_x, vert_y)
mat_vec = [ Date(2015,08,17), Date(2015,08,18), Date(2015,08,19), Date(2015,08,20), Date(2015,08,21), Date(2015,08,22)]
@test_approx_eq zero_rate(curve_ac365_simple_linear, mat_vec) [0.0875,0.1,0.1125,0.1250,0.1375,0.15]
@test_approx_eq ERF(curve_ac365_simple_linear, mat_vec) [1.00239726027397, 1.00301369863014, 1.00369863013699, 1.00445205479452, 1.00527397260274, 1.00616438356164]
@test_approx_eq discountfactor(curve_ac365_simple_linear, mat_vec) [0.997608472839084, 0.996995356459984, 0.996314999317592, 0.995567678145244, 0.994753696259454, 0.993873383253914]

println("discountfactor for Linear interpolation on vector with simple compounding")
@time discountfactor(curve_ac365_simple_linear, mat_vec)
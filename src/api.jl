# General api
"""
    formula(trm::TableRegressionModel)
    formula(model::MixedModel)

Unify formula api.
"""
formula(model) = error("formula is not defined for $(typeof(model)).")

"""
    nestedmodels(trm::TableRegressionModel{<: LinearModel}; null::Bool = false, <keyword arguments>)
    nestedmodels(trm::TableRegressionModel{<: GeneralizedLinearModel}; null::Bool = false, <keyword arguments>)
    nestedmodels(model::LinearMixedModel; null::Bool = false, <keyword arguments>)

    nestedmodels(::Type{LinearModel}, formula, data; null::Bool = true, <keyword arguments>)
    nestedmodels(::Type{GeneralizedLinearModel}, formula, data, distr::UnivariateDistribution, link::Link = canonicallink(d); null::Bool = true, <keyword arguments>)
    nestedmodels(::Type{LinearMixedModel}, f::FormulaTerm, tbl; null::Bool = true, wts = [], contrasts = Dict{Symbol, Any}(), verbose::Bool = false, REML::Bool = false)

Generate nested models from a model or formula and data. \n
The null model will be a model with at least one factor (including intercept) if the link function does not allow factors to be 0 (factors in denominators). \n
* `InverseLink` for `Gamma`
* `InverseSquareLink` for `InverseGaussian`
* `LinearModel` fitted with `CholeskyPivoted` when `dropcollinear = true`
Otherwise, it will be an empty model.
"""
nestedmodels(model) = error("nestedmodels is not defined for $(typeof(model)).")

# implement drop1/add1 in R?

const FixDispDist = Union{Bernoulli, Binomial, Poisson}
"""
    canonicalgoodnessoffit(::FixDispDist) = LRT
    canonicalgoodnessoffit(::UnivariateDistribution) = FTest

    const FixDispDist = Union{Bernoulli, Binomial, Poisson}
    
Return LRT if the distribution has a fixed dispersion.
"""
canonicalgoodnessoffit(::FixDispDist) = LRT
canonicalgoodnessoffit(::UnivariateDistribution) = FTest

"""
    anova(<models>...; test::Type{<: GoodnessOfFit})

Analysis of variance. \n
Return `AnovaResult{M, test, N}`. See `AnovaResult` for details.

* `models`: model objects
    1. `TableRegressionModel{<: LinearModel}` fit by `GLM.lm`
    2. `TableRegressionModel{<: GeneralizedLinearModel}` fit by `GLM.glm`
    3. `LinearMixedModel` fit by `MixedAnova.lme` or `fit(LinearMixedModel, ...)`
    If mutiple models are provided, they should be nested and the last one is the most saturated.
* `test`: test statistics for goodness of fit. Available tests are `LikelihoodRatioTest` (`LRT`) and `FTest`. \n
    If no test argument is provided, the function will automatically determine based on the model type:
    1. `TableRegressionModel{<: LinearModel}`: `FTest`.
    2. `TableRegressionModel{<: GeneralizedLinearModel}`: based on distribution function, see `canonicalgoodnessoffit`.
    3. `LinearMixedModel`: `FTest` for one model fit; `LRT` for nested models.

When multiple models are provided:  
* `check`: allows to check if models are nested. Defalut value is true. Some checkers are not implemented now.
* `isnested`: true when models are checked as nested (manually or automatically). Defalut value is false. 

For fitting new models and conducting anova at the same time, \n
see `anova_lm` for `LinearModel`, `anova_glm` for `GeneralizedLinearModel`, `anova_lme` for `LinearMixedModel`.
"""
anova(model) = error("anova is not defined for $(typeof(model)).")

"""
    anova(::Type{FTest}, <model>; kwargs...)
    anova(::Type{FTest}, <models>...; kwargs...)

Analysis of Variance by F-test. \n
Return `AnovaResult{M, FTest, N}`. See `AnovaResult` for details.

* `type` specifies type of anova: 
    1. One `LinearModel` or `GeneralizedLinearModel`: 1, 2, 3 are valid
    2. One `LinearMixedModel`: 1, 3 are valid. 
    3. Others: only 1 is valid.  
* `adjust_sigma` determines if adjusting to REML when `LinearMixedModel` is fit by maximum likelihood.  \n
    The result will be slightly deviated from that of model fit by REML.
"""
anova(::Type{FTest}, model) = error("anova by F-test is not defined for $(typeof(model)).")

"""
    anova(::Type{LRT}, <model>; kwargs...)
    anova(::Type{LRT}, <models>...; kwargs...)

Analysis of Variance by likelihood-ratio test. \n
Return `AnovaResult{M, LRT, N}`. See `AnovaResult` for details.
"""
anova(::Type{LRT}, model) = error("anova by likelihood-ratio test is not defined for $(typeof(model)).")

# across different kind of models
function _lrt_nested(models::NTuple{N, RegressionModel}, df, dev, σ²; nestedwarn::Bool = true) where N
    nestedwarn && @warn "Could not check whether models are nested: results may not be meaningful"
    Δdf = _diff(df)
    Δdev = _diffn(dev)
    lrstat = Δdev ./ σ²
    pval = map(zip(Δdf, lrstat)) do (dof, lr)
        lr > 0 ? ccdf(Chisq(dof), lr) : NaN
    end
    AnovaResult{LRT}(models, 1, df, dev, (NaN, lrstat...), (NaN, pval...), NamedTuple())
end

"""
    isnullable(::CholeskyPivoted)
    isnullable(::Cholesky
    isnullable(::InverseLink)
    isnullable(::InverseSquareLink)
    isnullable(::Link)
    isnullable(::LinearModel)
    isnullable(model::GeneralizedLinearModel)
    isnullable(::LinearMixedModel)

Return `true` if empty model can be fitted.
"""
isnullable(m) = error("isnullable is not defined for $(typeof(m)).")

"""
    nobs(aov::AnovaResult{<: Tuple})
    nobs(aov::AnovaResult)

Apply `nobs` to all models in `aov.model`
"""
nobs(aov::AnovaResult{<: Tuple}) = nobs.(aov.model)
nobs(aov::AnovaResult) = nobs(aov.model)

"""
    dof(aov::AnovaResult)

Degree of freedom of models or factors.
"""
dof(aov::AnovaResult) = aov.dof

"""
    dof_residual(aov::AnovaResult{<: Tuple})
    dof_residual(aov::AnovaResult)
    dof_residual(aov::AnovaResult{<: MixedModel, FTest})

Degree of freedom of residuals.
Default is applying `dof_residual` to models in `aov.model`.
For `MixedModels` applying `FTest`, it is calculated by between-within method. See `calcdof` for details.
"""
dof_residual(aov::AnovaResult{<: Tuple}) = dof_residual.(aov.model)
dof_residual(aov::AnovaResult) = dof_residual(aov.model)

"""
    deviance(aov::AnovaResult)

Return the stored devaince. The value repressents different statistics for different models and tests.
1. `LinearModel`: Sum of Squares.
2. `GeneralizedLinearModel`: `deviance(model)`
3. `LinearMixedModel`: `NaN` when applying `FTest`; `-2loglikelihood(model) == deviance(model)` when applying `LRT`.
When `LinearModel` is compared to `LinearMixedModel`, the deviance is alternatively `-2loglikelihood(model)`.
"""
deviance(aov::AnovaResult) = aov.deviance

"""
    teststat(aov::AnovaResult)

Values of test statiscics of `anova`.
"""
teststat(aov::AnovaResult) = aov.teststat

"""
    teststat(aov::AnovaResult)

P-values of test statiscics of `anova`.
"""
pval(aov::AnovaResult) = aov.pval

"""
    anova_test(::AnovaResult)

Test statiscics of `anova`.
"""
anova_test(::AnovaResult{M, T}) where {M, T <: GoodnessOfFit} = T

"""
    anova_type(aov::AnovaResult)

Type of `anova`.
"""
anova_type(aov::AnovaResult) = aov.type
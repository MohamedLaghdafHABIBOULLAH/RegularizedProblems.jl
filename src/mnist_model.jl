export tanh_train_model, tanh_test_model#, tan_nls_model
using MLDatasets
function tan_data_train()
  #load data
  A, b = MNIST.traindata();
  ind = findall(x -> x == 0 || x == 1, b);
  #reshape to matrix
  A = reshape(A,size(A,1)*size(A,2), size(A,3))./255;

  #get 0s and 1s
  b = b[ind]
  b[b.==0] .= -1
  A = convert(Array{Float64, 2}, A[:, ind])

  x0 = ones(size(A,1))
  A, b, x0
end

function tan_data_test()
  A0, b0 = MNIST.testdata();
  ind = findall(x -> x == 0 || x == 1, b)
  A0 = reshape(A0,size(A0,1)*size(A0,2), size(A0,3))./255

  #get 0s and 1s
  b0 = b0[ind]
  b0[b0.==0] .= -1
  A0 = convert(Array{Float64, 2}, A0[:, ind])

  x0 = ones(size(A0,1))
  A0, b0, x0
end

"""
    model, sol = bpdn_model(args...)
    model, sol = bpdn_model(compound = 1, args...)

Return an instance of an `NLPModel` representing the basis-pursuit denoise
problem, i.e., the under-determined linear least-squares objective

   f(x) = ‖∑ 1 - tanh(bᵢ⋅⟨aᵢ, x⟩)‖²,
   h(x) = ‖ ⋅ ‖

where A is a matrix and b = A * x̄ + ϵ, x̄ is binary and ϵ is a noise
vector following a normal distribution with mean zero and standard deviation σ.

## Arguments

* `m :: Int`: the number of rows of A
* `n :: Int`: the number of columns of A (with `n` ≥ `m`)
* `k :: Int`: the number of nonzero elements in x̄
* `noise :: Float64`: noise amount ϵ (default: 0.01).

The second form calls the first form with arguments

    m = 200 * compound
    n = 512 * compound
    k =  10 * compound

## Return Value

An instance of a `FirstOrderModel` that represents the basis-pursuit denoise problem
and the exact solution x̄.
"""
function tanh_train_model()
  A, b, x0 = tan_data_train()
  Ahat = Diagonal(b)*A';
  r = zeros(size(Ahat,1))

  function resid!(r, x)
    mul!(r, Ahat, x)
    r .= 1 .- tanh.(r)
    r
  end
  function resid(x)
    return 1 .- tanh.(Ahat * x)
  end

  function jacv!(Jv, x, v)
    mul!(r, Ahat, x)
    mul!(Jv, -Ahat, v)
    Jv .= ((sech.(r)).^2) .* Jv
  end
  function jactv!(Jtv, x, v)
    mul!(r, Ahat, x)
    tmp = -Diagonal(((sech.(r)).^2))*Ahat;
    mul!(Jtv, tmp', v)
    # v .= -((sech.(r)).^2) .* v
    # mul!(Jtv, Ahat', v)
  end
  function obj(x)
    resid!(r, x)
    dot(r, r) / 2 # can switch back
    # sum(r)
  end

  function grad!(g, x)
    mul!(r, Ahat, x)
    r .= (1 .- (sech.(r)).^2)
    # commented out is sum(r) gradient
    # r .= (1 .- tanh.(b .* r).^2) .* b
    mul!(g, -Ahat, r)
    g
  end

  FirstOrderModel(obj, grad!, ones(size(x0)), name = "MNIST-tanh"), FirstOrderNLSModel(resid!, jacv!, jactv!, size(b,1), x0), resid!, resid, b
end

function tanh_test_model()
  A, b, x0 = tan_data_test()
  r = zeros(size(A,2))

  function resid!(r, x)
    mul!(r, A', x)
    r .= 1 .- tanh.(b .* r)
    r
  end

  function obj(x)
    resid!(r, x)
    dot(r, r) / 2 # can switch back
    # sum(r)
  end

  function grad!(g, x)
    mul!(r, A', x)
    r .= tanh.(b .* r)
    r .= (1 .- r) .* (1 .- r.^2) .* b
    # r .= (1 .- tanh.(b .* r).^2) .* b
    mul!(g, -A, r)
    g
  end

  # function jac_residual!(J, x)

  # end

  FirstOrderModel(obj, grad!, ones(size(x0)), name = "MNIST-tanh"), resid, b
end

function mnist_model(; kwargs...)
  model_train, resid, sol = tanh_train_model()
  model_test, resid_test, sol = tanh_test_model()


end

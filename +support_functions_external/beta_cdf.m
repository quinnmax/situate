function support = beta_cdf(x,varargin)

    % wrap p(x|bx y by) in a beta cdf function (fit over multiple object types and baking in some
    % assumptions about priors)

    
    
    if numel(varargin) > 0
        model_in = varargin{1};
    end
    
    if numel(varargin) > 1
        ooi = varargin{2};
    end
    
    if exist('model_in','var') && exist('ooi','var')
        % during training
        p_x = model_in.situation_model.p_x;
        pbx_nx = model_in.situation_model.bx;
        % bootstrap
        beta_params_per_obj = [ 0.3349    2.0122
                                0.2984    5.3413
                                0.3993   13.0179];
        beta_params = beta_params_per_obj(ooi,:);
    else
        % during training
        p_x =  .0152;
        pbx_nx = 6.8498e+10;
        % bootstrap
        beta_params = [0.2782    3.7088];
    end
       
   
    psi = double( log( pbx_nx ) + log(1-p_x) - log( x + .00001 ) - log( p_x ) );
    p_x_bxyby = ( 1 + exp(psi) ).^(-1);

    support = betacdf( double(p_x_bxyby), beta_params(1), beta_params(2) );
    
end

function support = expcdf_fit( x, varargin )

% support = expcdf_fit( x, model_in, object_of_interest_ind );
% support = expcdf_fit( x );
 
    if numel(varargin) > 0
        model_in = varargin{1};
        ooi = varargin{2};
    end
    
    persistent exp_params
    if isempty(exp_params)
        exp_params = nan(1,numel(model_in.classifier_model.classes));
    end
    if isnan(exp_params(ooi))
        exp_params(ooi) = mean(model_in.situation_model.iou_dist{ooi});
    end
    
    if exist('model_in','var') && exist('ooi','var')
        % during training
        p_x = model_in.situation_model.p_x(ooi);
        pbx_nx = model_in.situation_model.bx(ooi);
        % bootstrap
        exp_param = exp_params( ooi );
    else
        % during training
        p_x =  .0152;
        pbx_nx = 6.8498e+10;
        % bootstrap
        exp_param =   0.0644;
    end
       
    psi = double( log( pbx_nx ) + log(1-p_x) - log( x + .00001 ) - log( p_x ) );
    p_x_bxyby = ( 1 + exp(psi) ).^(-1);

    support = expcdf( double(p_x_bxyby), exp_param );
    
end
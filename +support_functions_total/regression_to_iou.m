
function support = regression_to_iou( internal, external, varargin )

    learned_models = varargin{1};
    oi = varargin{2};

    cur_auroc = repmat(learned_models.classifier_model.AUROCs(oi),numel(internal),1);

    px = learned_models.situation_model.p_x(oi);
    
    % from bootstrap
    b_pxcx = [ -28.4780
                12.7181
                18.0822
                 0.6263];
            
    log_odds_vect = repmat( log((1-px)./px), numel(internal),1);
    d = [internal 2*(cur_auroc-.5) log_odds_vect];

    p_x_cx_est = glmval( b_pxcx, d, 'logit' );
   
   
    
    % lasso regression to iou, with cdf_exp external support
        d = [1
            internal 
            external 
            p_x_cx_est
            internal .* external
            2*(cur_auroc-.5)
            2*(cur_auroc-.5) .* internal];
        b_linreg = [ 0
                     0
                     0.0587
                     0.0220
                     0.1036
                     0.2166
                     0.6430 ];
    
    iou_predicted = d' * b_linreg;
    support = iou_predicted;
    
end
     

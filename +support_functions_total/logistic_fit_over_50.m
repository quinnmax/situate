
function support = logistic_fit_over_50( internal, external, varargin )

    learned_models = varargin{1};
    oi = varargin{2};

    cx = internal;
    
    cur_auroc = repmat(learned_models.classifier_model.AUROCs(oi),numel(cx),1);

    px = learned_models.situation_model.p_x(oi);
    
    % figure out p(x|cx)
    b_pxcx = [  
      -56.8532
      -14.8807
       64.3906
       -3.2942
        6.8531 ];
    
    log_odds_vect = repmat( log((1-px)./px), numel(cx),1);
    d = [cx cur_auroc log_odds_vect log_odds_vect .* cx];
    p_x_cx_est = glmval( b_pxcx, d, 'logit' );
    
    % figure out p(x|bx,y,by)
    p_x_bx = external;
    
    
%     b_lasso_iou = [ 0; 0.2892; 0.3493; 0.1582 ];
%     total_sup_lasso_iou = [1, cx, cx * p_x_bx, p_x_cx_est] * b_lasso_iou;
%     support = total_sup_lasso_iou;
    
%     b_lasso_x = [0; 0.1468; 0.6597; 0.1206];
%     total_sup_lasso_x = [ones(numel(cx),1),  cx * p_x_bx, p_x_cx_est, cx .* (2*(cur_auroc-.5)) ] * b_lasso_x;
%     support = total_sup_lasso_x;
    

 % 'cx'    'cx * p(x|bx)'    'p(x|cx)'    'p(x|bx)'    'p(x|cx,bx)'    'auroc'    'cx * auroc'    'p(x|bx)*auroc'
b_logistic_x = [ -9.2721
  -16.4054
    0.1930
   -4.5740
   11.9730
   -0.9157
    2.9371
   32.5772
  -12.2620];
d = [cx 
    cx*p_x_bx 
    p_x_cx_est 
    p_x_bx 
    p_x_cx_est*p_x_bx
    cur_auroc
    cx*cur_auroc
    p_x_bx*cur_auroc];
    
    total_sup_logistic_x = glmval( b_logistic_x, d', 'logit' );
    support = total_sup_logistic_x;
    
    %exp_cdf_wrap = expcdf( total_sup_logistic_x, 0.1059 );
    %support = exp_cdf_wrap;
    
    
    
end
     

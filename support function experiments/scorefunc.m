function [output,c_func] = scorefunc( int, ext, target, quality_scores, t_in )

% scoring function for optimization of total support function

    
    % multiple priorities
    % - should be useful as decision value: minimize -ROC
    % - interpretable: correspondence with IOU or p>.5, using rmse with IOU
    % - distinguish in-situation obj from not in-sit: min external weight >= .1

    total_sup_func = @(int,ext,c) c * int + (1-c) * ext; 

    use_poly = false;
    
    if numel(t_in)>2
        if use_poly
            c_func = @(t,auc) t(1) + t(2) * (auc-t(3)).^2;
        else
            c_func = @(t,auc) t(1) + t(2) * (auc-t(3));
        end
    else
        if use_poly
            c_func = @(t,auc) t(1) + t(2) * auc.^2;
        else
            c_func = @(t,auc) t(1) + t(2) * auc;
        end
    end

    
    
    if size(int,1) > 50000
        subind = randperm(size(int,1),10000 );
    else
        subind = 1:size(int,1);
    end
    
    
    
    sub_score = nan(1,size(int,2));
    for oi = 1:size(int,2)
        sub_score(oi) = ...
            1 - ROC( total_sup_func( int(subind,oi), ext(subind,oi), c_func( t_in, quality_scores(oi) ) ), target(subind,oi)>.5 ) - .5...
            + ...
            .5 * rmse( total_sup_func( int(:,oi), ext(:,oi), c_func( t_in, quality_scores(oi) ) ), target(:,oi) );
    end
    
    output = mean(sub_score);
    %output = sum(sub_score) +  .1*max(internal_support_weights - .9);

    
    
end
    

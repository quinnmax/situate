function [auroc, tpr, fpr] = ROC( dvars, is_pos, varargin )
    
% [auroc, tpr, fpr] = ROC( decision_variables, is_positive_instance );
    
    if ~isempty(varargin) && isnumeric(varargin{1}) && varargin{1} < 0
        dvars = dvars * -1;
    end
    
    n = length(dvars);
    
    [~,ordering] = sort(dvars,'descend');
    is_pos = is_pos(ordering);
    
    tpr = arrayfun( @(x) sum(  is_pos(1:x) ), 1:n ) ./ sum( is_pos);
    fpr = arrayfun( @(x) sum( ~is_pos(1:x) ), 1:n ) ./ sum(~is_pos);
    
    % trapezoidal est averaging left and right Riemann sums
    auroc = ...
           mean([ 
                sum( tpr(1:end-1) .* abs((fpr(2:end) - fpr(1:end-1))) ), ...
                sum( tpr(2:end)   .* abs((fpr(2:end) - fpr(1:end-1)) )) ]);

            
end
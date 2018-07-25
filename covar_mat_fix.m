function [S,success] = covar_mat_fix(S)

% [S,success] = covar_mat_fix(S);
%   tries to keep S positive semi-definite, with
%       S = (S + S')/2;
%       S = S + eye(size(S,1)) * (min(diag(S))/1000);
%
%   if that fails, replaces it with .001 * I, returns false in success
        

    if ndims(S) > 2 %#ok<ISMAT>
        success = false(1,size(S,3));
        for ki = 1:size(S,3)
            [S(:,:,ki),success(ki)] = covar_mat_fix(S(:,:,ki));
        end
        return;
    end

    success = true;
    
    [~,P] = cholcov(S,0);
    if P~=0
        S = (S + S')/2;
        S = S + eye(size(S,1)) * (min(diag(S))/1000);
        [~,P] = cholcov(S,0);
        if P~=0
            S = eye(size(S,1)) * .001;
            success = false;
        end
    end
    
end
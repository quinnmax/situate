
function [model_return] = gmm_condition( model_in, want_inds, known_inds, known_vals )
% [model_return] = gmm_condition( model_in, want_inds, known_inds, known_vals )
%   want_data_inds should be a logical vector the same length as mu
%   have_data_inds should be a logical vector the same length as mu (or empty)
%   known data can either be length(mu), or length = sum(have_data_inds)
%   
%   features in mu_bar and Sigma_bar will be in their original order, 
%   excluding dimensions that were marginalized out or conditioned out
%
%   see also mvn_conditional, mvn_marginalize_and_condition_ts

    k = size(model_in.mu,1);
    
    just_marginalize = false;
    if isempty( known_inds ) || ~any(known_inds)
        just_marginalize = true;
    end
    
    % get marginalized clusters for known data
    marginal_densities = nan(k,1);
    for ki = 1:k
        
        marginalize_want = known_inds;
        [mu_bar, Sigma_bar] = mvn_marginalize_and_condition( model_in.mu(ki,:), model_in.Sigma(:,:,ki), marginalize_want, [], [] );
        
        if ~just_marginalize
            marginal_densities(ki) = mvnpdf( known_vals(known_inds), mu_bar, Sigma_bar);
        end
    
    end
    
    % condition on known data
    model_return = [];
    for ki = 1:k
        
        [mu_bar, Sigma_bar] = mvn_marginalize_and_condition( model_in.mu(ki,:), model_in.Sigma(:,:,ki), want_inds, known_inds, known_vals );
        model_return.mu(ki,:) = mu_bar;
        model_return.Sigma(:,:,ki) = Sigma_bar;
        
        if ~just_marginalize
            model_return.pi(ki) = model_in.pi(ki) * marginal_densities(ki) / sum( model_in.pi * marginal_densities );
        else
            model_return.pi(ki) = model_in.pi(ki);
        end
        
    end
    
    % try to keep it clean
    model_return.Sigma = covar_mat_fix(model_return.Sigma);
    
end
    
    













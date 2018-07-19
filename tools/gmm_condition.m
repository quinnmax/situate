
function [model_conditioned] = gmm_condition( model_in, want_inds, known_inds, known_vals )
% [mu_bar, Sigma_bar] = mvn_marginalize_and_condition( model_in, want_data_inds, have_data_inds, known_data )
%   want_data_inds should be a logical vector the same length as mu
%   have_data_inds should be a logical vector the same length as mu (or empty)
%   known data can either be length(mu), or length = sum(have_data_inds)
%   
%   features in mu_bar and Sigma_bar will be in their original order, 
%   excluding dimensions that were marginalized out or conditioned out
%
%   see also mvn_conditional, mvn_marginalize_and_condition_ts


    k = size(model_in.mu,1);
    
    % get marginalized clusters for known data
    marginal_densities = nan(k,1);
    for ki = 1:k
        
        marginalize_want = known_inds;
        [mu_bar, Sigma_bar] = mvn_marginalize_and_condition( model_in.mu(ki,:), model_in.Sigma(:,:,ki), marginalize_want, [], [] );
        marginal_densities(ki) = mvnpdf( known_vals, mu_bar, Sigma_bar);
    
    end
    
    % condition on known data
    
    model_conditioned = [];
    for ki = 1:k
        
        [mu_bar, Sigma_bar] = mvn_marginalize_and_condition( model_in.mu(ki,:), model_in.Sigma(:,:,ki), want_inds, known_inds, known_vals );
        model_conditioned.mu(ki,:) = mu_bar;
        model_conditioned.Sigma(:,:,ki) = Sigma_bar;
        
        model_conditioned.pi(ki) = model_in.pi(ki) * marginal_densities(ki) / sum( model_in.pi .* marginal_densities );
        
    end
    
end
    
    













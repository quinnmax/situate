
function [mu_bar, Sigma_bar] = mvn_marginalize_and_condition( joint_mu, joint_Sigma, want_data_inds, have_data_inds, known_data )

    % [mu_bar, Sigma_bar] = mvn_marginalize_and_condition( joint_mu, joint_Sigma, want_data_inds, have_data_inds, known_data )
    %   want_data_inds should be a logical vector the same length as mu, or indices
    %   have_data_inds should be a logical vector the same length as mu, indices, or empty
    %   known data can either be length(mu), or length = sum(have_data_inds)
    %   
    %   features in mu_bar and Sigma_bar will be in their original order, 
    %   excluding dimensions that were marginalized out or conditioned out
    %
    %   see also mvn_conditional, mvn_marginalize_and_condition_ts
    
    if ~exist('have_data_inds','var'), have_data_inds = []; known_data = []; end
    
    % special case
        if ~isempty(have_data_inds) && ~islogical(have_data_inds) && ~isequal(have_data_inds, sort(have_data_inds)) && length(known_data) == length(have_data_inds)
            [~,sort_order] = sort(have_data_inds);
            have_data_inds = have_data_inds(sort_order);
        end
    
    % get want_data_inds and have_data_inds into logical indexing
        
    if all(islogical(want_data_inds))
        % good
    elseif length(want_data_inds) == length(joint_mu) && isempty(setxor(unique(want_data_inds),[0 1]))
        % assume was meant to be logical
        want_data_inds = logical(want_data_inds);
    elseif length(want_data_inds) ~= length(joint_mu)
        % looks like inds, make logical
        want_data_inds_temp = false(size(joint_mu));
        want_data_inds_temp(want_data_inds) = true;
        want_data_inds = want_data_inds_temp;
    end
    
    if all(islogical(have_data_inds))
        % good
    elseif isempty(have_data_inds)
        % fine
    elseif length(have_data_inds) == length(joint_mu) && isempty(setxor(unique(have_data_inds),[0 1]))
        % assume was meant to be logical
        have_data_inds = logical(have_data_inds);
    elseif length(have_data_inds) ~= length(joint_mu)
        % looks like inds, make logical
        have_data_inds_temp = false(size(joint_mu));
        have_data_inds_temp(want_data_inds) = true;
        have_data_inds = have_data_inds_temp;
    end
    
    % just some assertions about have data vals
    assert( isempty(have_data_inds) ...
          | length(known_data) == length(joint_mu) ...
          | length(known_data) == sum(have_data_inds) );
    
    if length(have_data_inds) == length(want_data_inds)
        relevant_inds  = or(have_data_inds, want_data_inds); % dimensions to keep. marginalize out the rest right off
    else
        if all(islogical(want_data_inds))
            want_data_inds = find(want_data_inds);
        end
        % assume they're indicies, not Boolean indexing
        temp_inds = unique([want_data_inds, have_data_inds]);
        relevant_inds = false(1,length(joint_mu));
        relevant_inds(temp_inds) = true;
    end
    
    % marginalize out everything but the known data and the desired variables
    % ( just remove the irrelevant parts of mu and Sigma for MVNs )
    marginal_mu    = joint_mu(relevant_inds); 
    marginal_Sigma = joint_Sigma( logical(double(relevant_inds)' * double(relevant_inds)) );
    marginal_Sigma = reshape(marginal_Sigma,[sum(relevant_inds) sum(relevant_inds)]);
    
    % see if marginalizing was it. if so, return
    if isempty(have_data_inds) || ~any(have_data_inds)
        mu_bar = marginal_mu;
        Sigma_bar = marginal_Sigma;
        return;
    end
    
    % clean up what we have based on the marginalization
    want_data_inds( ~relevant_inds ) = [];
    have_data_inds( ~relevant_inds ) = [];
    known_data(     ~relevant_inds ) = [];
    
    % then use the known values to build the conditional distribution
    if any(have_data_inds)
        [mu_bar, Sigma_bar] = mvn_conditional( marginal_mu, marginal_Sigma, have_data_inds, known_data );
    else
        mu_bar    = marginal_mu;
        Sigma_bar = marginal_Sigma;
    end
    
    Sigma_bar = (Sigma_bar + Sigma_bar.') / 2;
    
end











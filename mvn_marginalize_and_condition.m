
function [mu_bar, Sigma_bar] = mvn_marginalize_and_condition( joint_mu, joint_Sigma, want_data_inds, have_data_inds, known_data )

    relevant_inds  = or(have_data_inds, want_data_inds); % dimensions to keep. marginalize out the rest right off

    % marginalize out everything but the known data and the desired variables
    % ( just remove the irrelevant parts of mu and Sigma for MVNs )

    marginal_mu    = joint_mu(relevant_inds); 
    marginal_Sigma = joint_Sigma( logical(double(relevant_inds)' * double(relevant_inds)) );
    marginal_Sigma = reshape(marginal_Sigma,[sum(relevant_inds) sum(relevant_inds)]);

    % clean up what we have based on the marginalization

    want_data_inds( ~relevant_inds ) = [];
    have_data_inds( ~relevant_inds ) = [];
    known_data(     ~relevant_inds ) = [];
    
    % then use the known values to build the conditional distribution

    if any(have_data_inds)
        [mu_bar, Sigma_bar] = mvn_conditional( marginal_mu, marginal_Sigma, have_data_inds, known_data );
    else
        mu_bar = marginal_mu;
        Sigma_bar = marginal_Sigma;
    end
    
end













function [mu_bar, Sigma_bar] = mvn_conditional( mu, Sigma, known_dimensions, known_values )

    % [mu_conditional Sigma_conditional] = mvn_conditional( mu_joint, Sigma_joint, known_dimensions, known_values );
    %
    % mu_joint and Sigma_joint are for the joint distribution from the full
    % data set
    %
    % known_dimensions is a boolean vector of dimenions that we have known values
    % for. or it can be a vector of the indices of the known dimensions.
    % For example, [true true false true] and [1 2 4] will produce the same
    % result.
    %
    % known_values is a vector of the known values. It can either have as
    % many elements as there are known dimensions, or it
    % can be the length of mu (the total number of dimensions), with values
    % in the unknown positions that will be ignored.
    % For example, given the above known_dimensions, for which it is
    % indicated that there are 3 known values,
    % [.5 1 2] and [.5 1 0 2] will produce the same result.
    %
    % see also mvn_conditional_ts, mvn_marginalize_and_condition

    % _2 will be for the known dimensions

    if length(known_dimensions) ~= length(mu)
        % assume they're a list of indices instead of a boolean indicator
        % vector
        temp = false(length(mu),1);
        temp(known_dimensions) = true;
        known_dimensions = temp;
        % if the values don't work as indices of known values, then this
        % should bonk.
    else
        known_dimensions = logical( reshape(known_dimensions,[],1 ) );
    end
    
    if length(known_values) < length(mu)
        % assume they provided these in the right order and go with it.
        a = reshape( known_values, [], 1 );
    else
        a = reshape( known_values( known_dimensions ), [], 1 );
    end
    
    mu_1 = mu(~known_dimensions)';
    mu_2 = mu( known_dimensions)';
    
    q = sum( ~known_dimensions ); % num of unknown dims
    N = length( known_dimensions ); % total dims

    Sigma_11_inds = logical( double(~known_dimensions ) * double(~known_dimensions' ) );
    Sigma_22_inds = logical( double( known_dimensions ) * double( known_dimensions' ) );
    Sigma_12_inds = logical( double(~known_dimensions ) * double( known_dimensions' ) );
    Sigma_21_inds = logical( double( known_dimensions ) * double(~known_dimensions' ) );
    
    Sigma_11 = reshape( Sigma( Sigma_11_inds ), q, q );
    Sigma_22 = reshape( Sigma( Sigma_22_inds ), N-q, N-q );
    Sigma_12 = reshape( Sigma( Sigma_12_inds ), q, N-q );
    Sigma_21 = reshape( Sigma( Sigma_21_inds ), N-q, q );
    
    mu_bar    = (mu_1 + Sigma_12 / Sigma_22 * (a - mu_2))';
    Sigma_bar = Sigma_11 - Sigma_12 / Sigma_22 * Sigma_21;
    
end

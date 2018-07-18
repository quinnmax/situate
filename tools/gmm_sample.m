
function [x, densities, responsibilities ] = gmm_sample( model, n )

%[samples, densities, responsibilities ] = function gmm_sample( model, n );
% model should have:
%   mu: row per cluster, col per feature
%   Sigma: row,col per feature, layer per cluster
%   pi: entry per cluster

    k = size(model.mu,1);
    dims = size(model.mu,2);
    x = nan( k, dims );

    cluster_inds = sample_1d( model.pi, n );

    for ni = 1:n
        ki = cluster_inds(ni);
        x( ni,: ) = mvnrnd( model.mu(ki,:), model.Sigma(:,:,ki) );
    end

    densities_temp = zeros(n,k);
    for ki = 1:k
        densities_temp(:,ki) = repmat(model.pi(ki),n,1) .* mvnpdf( x, model.mu(ki,:), model.Sigma(:,:,ki) );
    end
    densities = sum(densities_temp,2);
    
    responsibilities = zeros(n,k);
    for ki = 1:k
        S_temp = model.Sigma(:,:,ki);
        S_temp = S_temp + S_temp' / 2;
        responsibilities(:,ki) = repmat(model.pi(ki),n,1) .* mvnpdf( x, model.mu(ki,:), S_temp );
    end
    
    

end











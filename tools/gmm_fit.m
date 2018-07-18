function models = gmm_fit( x, k )

    % models = gmm_fit( x, k );
    % where x is the data and k is the number of clusters
    % models is a k entry struct with mu, Sigma, and pi (prior)
    
    n = size(x,1);
    
    % set some initial estimates based on x
    temp = linspace(0,100,2*k+1);
    % just a line in n-space
    m = zeros(k,size(x,2));
    for i = 1:size(x,2)
        m(:,i) = prctile(x(:,i),temp(2:2:end-1));
    end
    % equal variance covariance matricies
    S = repmat( cov(x)/(k^2), [1, 1, k] );
    %S = repmat([1000 0; 0 1000], [1,1,k] );
    p = 1/k * ones(1,k);
    
    iterations = 20;
    for iter = 1:iterations

        % expectation
        %   for each example, decided on how much we think it belongs to dist 1
        %   vs dist 2, that is, give each a responsibility value

            px = zeros(size(x,1),k);
            for ki = 1:k
                S_temp =  S(:,:,ki);
                S_temp = S_temp + S_temp' / 2;
                px(:,ki) = repmat(p(ki),n,1) .* mvnpdf( x, m(ki,:), S_temp );
            end

        % gamma, the weight, is the probability of a centroid given the data
        %
        % using bayes rule, that's the p(x|centroid)*p(centroid)/p(x)
        % p(x|centroid) * p(centroid) = px
        % p(x) = sum(px,2)

            gamma = px ./ repmat(sum(px,2),1,k);

        % maximization
        %   now, with some responsibility estimates, adjust the model
        %   parameters so that each dist accounts for the data in proportion to
        %   how much responsibility it has for the instances

            for ki = 1:k
                m(ki,:) = sum( repmat(gamma(:,ki),1,size(x,2)) .* x ) ./ repmat(sum(gamma(:,ki)),1,size(x,2));
                temp = (x - repmat(m(ki,:),n,1));
                a = temp';
                b = repmat(gamma(:,ki),1,size(x,2)) .* temp;
                S(:,:,ki) = (a*b) ./ sum(gamma(:,ki));
            end
            p = (1/n) * sum(gamma);
            
    end

    
    models = [];
    for ki = 1:k
        models(ki).mu = m(ki,:);
        models(ki).sigma = S(:,:,ki);
        models(ki).pi = p(ki);
    end
    
end
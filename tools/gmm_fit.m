function [model, log_lik, alt_models] = gmm_fit( x, varargin )

    % [models, log_lik_per_iter, alt_models] = gmm_fit( x, k, [num_iterations], [repeated_trials] );
    % where x is the data and k is the number of clusters
    % models is a k entry struct with mu, Sigma, and pi (prior)
    
    if length(varargin) > 2
        repeated_trials = varargin{3};
        num_iterations  = varargin{2};
        k               = varargin{1};
        temp = cell(1,repeated_trials);
        log_lik_per_iter = nan(repeated_trials, num_iterations);
        for ti = 1:repeated_trials
            
            [temp{ti},log_lik_per_iter(ti,:)] = gmm_fit( x, k, num_iterations );
        
        end
        [~,win_ind] = max(log_lik_per_iter(:,end));
        model = temp{win_ind};
        log_lik = log_lik_per_iter([win_ind setsub(1:repeated_trials,win_ind)],:);
        alt_models = temp([win_ind setsub(1:repeated_trials,win_ind)]);
        return;
    end
    
    if length(varargin) > 1
        k = varargin{1};
        iterations = varargin{2};
    end
        
    if length(varargin) == 1
        k = varargin{1};
        iterations = 50;
    end
    
    if length(varargin) < 1
        k = 1;
        iterations = 50;
    end
    
  
    
    n = size(x,1); % num exemplars
    dims = size(x,2); % num dimensions
    
    % set some initial estimates based on x
    %   stepping through percentiles
    temp = linspace(0,100,2*k+1);
    % just a line in n-space
    m = zeros(k,dims);
    for i = 1:dims
        m(:,i) = prctile(x(:,i),temp(2:2:end-1));
        m(:,i) = m(randperm(k,k),i);
    end
    m = m + randn(size(m));
    
    % equal variance covariance matricies
    % S = repmat( cov(x)/(k^2), [1, 1, k] );
    %     S = zeros(dims,dims,1);
    %     S(logical(eye(dims))) = var(x)/(k^2);
    %     S = repmat(S,[1,1,k]);
    S = repmat( eye(dims), [1,1,k] );    

    
    p = 1/k * ones(k,1);
    
    log_lik = zeros(1,iterations);
    
    for iter = 1:iterations

        % expectation
        %   for each example, attribute its density to clusters

            px = zeros(size(x,1),k);
            for ki = 1:k
                px(:,ki) = repmat( p(ki),n,1) .* mvnpdf( x, m(ki,:), S(:,:,ki) );
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
                m(ki,:) = sum( repmat(gamma(:,ki),1,dims) .* x ) ./ repmat(sum(gamma(:,ki)),1,dims);
                temp = (x - repmat(m(ki,:),n,1));
                a = temp';
                b = repmat(gamma(:,ki),1,dims) .* temp;
                S(:,:,ki) = (a*b) ./ sum(gamma(:,ki));
            end
            
            p = (1/n) * sum(gamma);
            
        % try to keep S in good shape
            [S,success] = covar_mat_fix(S);
        % try to reassign failed clusters to poorly supported points (low end, but not bottom)
            if ~all(success)
                failed_clusters = find(~success);
                instance_support = log(sum(px,2));
                [~,sort_order] = sort(instance_support);
                replace_inds = round(linspace(0,.25,length(failed_clusters)+2)*n);
                replace_inds = replace_inds(2:end-1);
                m(failed_clusters,:) = x( sort_order( replace_inds ), : );
            end
            
        log_lik(iter) = sum(log(gmmpdf( x, m, S, p )));
            
    end

    
    
    model.mu = m;
    model.Sigma = S;
    model.pi = p;
   
    
    
end


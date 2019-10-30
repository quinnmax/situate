function support = logistic_normalized_dist(x)
    
    % based on just poking at density values from training data. 
    % used for continuous, unit area, centered at origin distribution

    % support = logistic( log(x), .1 );
    
    % fit using exploratory data, trying to match empirical cdf
    b = [ 0.0314, 0.8241, 0.0674, 0.0342 ];
    support = b(1) + b(2) * logistic(log(x) - b(4),b(3));
    
    
    
end

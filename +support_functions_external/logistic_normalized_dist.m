function support = logistic_normalized_dist(x)
    
    % based on just poking at density values from training data. 
    % used for continuous, unit area, centered at origin distribution

    support = logistic( log(x), .1 );
    
end

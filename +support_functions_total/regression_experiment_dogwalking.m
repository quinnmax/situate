function support = regression_experiment_dogwalking( internal, external, varargin )

    % bootstrap re-estimation based on validation set run
    b = [   0.1210    0.8053   -0.0033    0.0220; ...
            0.0568    0.8975   -0.0001   -0.0204; ...
            0.1383    0.5683    0.1271    0.1949 ];
    
    x = [ 1; internal; external; internal * external ];
    
    support = b * x;
    
end
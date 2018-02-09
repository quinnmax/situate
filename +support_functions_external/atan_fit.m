function support = atan_fit( x )

    % bootstrapped and fit to the following target function of density percentile: 
    %   x_target_function = [ 0  .5  .9   1 ];
    %   y_target_function = [ 0   0   1   1 ];
    % where x is the density percentile from a validation experiment run.
    % upto the 50th percentile, roughly zero external support
    % from 50th to 90th, active region, linear increase in external support
    % from 90th to 100th, saturation, external support 1
    activation_function = @(x,b) b(1) + b(2) * atan( b(3) * (x-b(4)) );
    b = [ 0.0237, 0.6106, 4.4710e-12, -0.3192 ];
    
    support = activation_function( x, b );
    
end
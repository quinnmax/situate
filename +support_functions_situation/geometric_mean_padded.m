function support = geometric_mean_padded( total_support_values, varargin )
    
    support = prod(total_support_values + .01).^(1/length(total_support_values));
    
end
            
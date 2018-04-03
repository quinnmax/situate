function out = softmax_dim( in, dim )
% out = softmax_dim( in, dim )

    e_in = exp(in);
    e_sum = sum( e_in, dim );
    
    out = e_in ./ e_sum;
    
end
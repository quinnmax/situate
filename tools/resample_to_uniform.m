function [inds_out, vals_out] = resample_to_uniform( vals_in, n, num_bins )

    % [inds_out, vals_out] = resample_to_uniform( vals_in, n, num_bins );
    %
    %   Given a collection of samples, this resamples them to make them look more uniformly
    %   distributed, and returns the resampling indices (and the actually resampled values if
    %   desired). 
    %
    %   n defaults to the length of vals_in
    %   num_bins defaults to 30, uniformly dispersed through the range of vals_in
    %
    %   Original use for this is to make it easier to train on data that's poorly distributed. I
    %   have a lot of low output value examples and fewer high output value examples. I'd like to
    %   trim down the low-output value examples and maybe repeat a few of the high value examples.
    
    %vals_in = randn(1,1000);
    
    if ~exist('n','var') || isemty(n)
        n = length(vals_in);
    end
    
    if ~exist('num_bins','var') || isempty(num_bins)
        num_bins = 30;
    end
   
    vals_out_per_bin = round(n / num_bins);
    assert( vals_out_per_bin > 1 );
    
    bin_bounds = linspace( min(vals_in), max(vals_in), num_bins+1 );
    bin_bounds(1) = -inf;
    bin_bounds(end) = inf;
    
    inds_out = [];
    
    for bi = 1:length(bin_bounds)-1
        inds_in_cur_range = find( ge( vals_in, bin_bounds(bi) ) & lt( vals_in, bin_bounds(bi+1) ) );
        inds_out(end+1:end+vals_out_per_bin) = inds_in_cur_range( randi(length(inds_in_cur_range),1,vals_out_per_bin) );
    end
    
    vals_out = vals_in(inds_out);
    
%     figure
%     subplot(1,2,1)
%     hist(vals_in,20)
%     subplot(1,2,2)
%     hist(vals_out,20)
    
end
    
    
    
    
    
    
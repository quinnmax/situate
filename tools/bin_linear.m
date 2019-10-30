function [bin_assignments,bin_edges,bin_centers] = bin_linear(x,input)

% [bin_assignments,bin_edges,bin_centers] = bin_linear(x,num_bins);
% [bin_assignments,bin_edges,bin_centers] = bin_linear(x,bin_edges);
%
%  x > bin_edges(1:end-1) and x < bin_edges(2:end). outside will be missed, so bin accordingly

if ~exist('input','var') || isempty(input)
    input = 10;
end

if numel(input) == 1
    num_bins = input;
    bin_edges = linspace(min(x),max(x),num_bins+1);
    bin_edges = [bin_edges(1:end-1) inf];
    temp1 = x <=  bin_edges(2:end);
    temp2 = x > bin_edges(1:end-1);
    temp3 = temp1 & temp2;
else
    bin_edges = input;
end

    temp = x < bin_edges(2:end);
    bin_assignments = argmax( logical( temp - [zeros(size(temp,1),1) temp(:,1:end-1)] ), [], 2 );
    
    bin_centers = bin_edges(2:end) - median(diff(bin_edges))/2;
    bin_centers(end) = bin_edges(end-1) + median(diff(bin_edges))/2;
    
   
end
    
    
    
    
    
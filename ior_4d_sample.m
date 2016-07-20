function [s_ind,x_out] = ior_4d_sample( x, h_in, inhibition_intensity, method )
% [s_ind,x_out] = ior_4d_sample( x, h_in, inhibition_intensity, method );
%
%   x is the 4d sampling space
%
%   h_in is either an inhibition size specification (like [15 15 7 5])
%   OR h_in is the actual inhibition filter (of size like [15 15 7 5] )
%   
%   inhibition_intensity is how much to inhibit the sample point. keep at 1
%   for now
%
%   method is either 'peak' or 'sample'. 
%
%
%
%   s_ind is the index of the sampled location from x
%
%   x_out is x with inhibition around the sampled point s_ind

    if ~exist('method','var') || isempty(method)
        method = 'peak';
        % method = 'sample';
    end

    if ~exist('inhibition_intensity','var') || isempty(inhibition_intensity)
        inhibition_intensity = 1;
    end

    if numel(h_in) == length(size(x))
        % then we'll assume h is a specification, not the actual block
        inhibition_widths = h_in;
        
        persistent h;
        if isempty('h') || length(inhibition_widths) ~= length(size(h)) || ~all( inhibition_widths == size(h) )
            temp1 = repmat( blackman(inhibition_widths(1)) * blackman(inhibition_widths(2))', 1,1,inhibition_widths(3),inhibition_widths(4) );
            temp2 = repmat( reshape(blackman(inhibition_widths(3)),1,1,[],1), inhibition_widths(1),inhibition_widths(2),1,inhibition_widths(4) );
            temp3 = repmat( reshape(blackman(inhibition_widths(4)),1,1,1,[]), inhibition_widths(1),inhibition_widths(2),inhibition_widths(3),1 );
            inhibition_mask_temp = temp1 .* temp2 .* temp3;
            h = 1 - ( inhibition_intensity * mat2gray(inhibition_mask_temp) );
        end

    else
        % we'll assume it's the inhibition block and do nothing
        inhibition_widths = size(h_in);
        h = h_in;
    end
    
    switch method
        case 'peak'
            [~,linear_ind] = max(x(:));
        case 'sample'
            [~,linear_ind]= sample_nd( x, [], 1 );
        otherwise
            error('unkown method');
    end
    
    s_ind = ind2sub2(size(x),linear_ind);
    
    % inhibit the sampled location
    
    x_out = x;
    block_i0 = zeros(1,length(size(x)));
    block_if = zeros(1,length(size(x)));
    filt_i0  = zeros(1,length(size(x)));
    filt_if  = zeros(1,length(size(x)));
    
    for di = 1:length(size(x))     % dimension index

        block_i0(di) = s_ind(di) - floor(inhibition_widths(di)/2);
        block_if(di) = block_i0(di) + inhibition_widths(di) - 1;

        if block_i0(di) < 1
            filt_i0(di) = 1 + (1-block_i0(di));
            block_i0(di) = 1;
        else
            filt_i0(di) = 1;
        end

        if block_if(di) > size(x,di)
            filt_if(di) = inhibition_widths(di) - (block_if(di) - size(x,di));
            block_if(di) = size(x,di);
        else
            filt_if(di) = inhibition_widths(di);
        end

    end

    x_out( ...
        block_i0(1):block_if(1), ...
        block_i0(2):block_if(2), ...
        block_i0(3):block_if(3), ...
        block_i0(4):block_if(4) ) = ...
            x_out( ...
                block_i0(1):block_if(1), ...
                block_i0(2):block_if(2), ...
                block_i0(3):block_if(3), ...
                block_i0(4):block_if(4) ) .* ...
            h( ...
                filt_i0(1):filt_if(1), ...
                filt_i0(2):filt_if(2), ...
                filt_i0(3):filt_if(3), ...
                filt_i0(4):filt_if(4) );
            
end
                
    
        
    






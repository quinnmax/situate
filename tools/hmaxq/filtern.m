function y = filtern(h,x)

    % y = filtern(h,x);
    %
    % filters x with h, layer to layer. 
    % sum(y,3) will give total activation. 
    %
    % if size(h,3) < size(x,3), each layer of x is filtered by h(:,:,1)
    % if size(h,3) > size(x,3), x(:,:,1) is filtered by each layer of h 
    %
    % uses replicated padding and returns a map the same size as
    % the input x.
    

    

    % pad the x array
    
        [pr pc] = size(h);
        xp = padarray( x, [pr pc], 'replicate' );
    
        
    
    % compute the first layer
    % if there's a mismatch in the size of the filter or signal,
    % used repeated filter or signal as necessary
    
        y(:,:,1) = filter2( h(:,:,1), xp(:,:,1), 'same' );
        
        if size(h,3) < size(xp,3)
            
            % if the image has fewer layers, only use its first layer
            % and apply each layer of the filter to it 
            % (eg, a stack of gabors being applied to a single input image)
            
            y(:,:,2:size(xp,3)) = 0;
            for i = 2:size(xp,3)
                y(:,:,i) = filter2( h(:,:,1), xp(:,:,i), 'same' );
            end
            
        elseif size(xp,3) < size(h,3)
        
            % if the filter has fewer layers, only use its first layer
            % on each layer of the input
            % (should happen much, a bit of a degenerate situation)
            
            y(:,:,2:size(h,3)) = 0;
            for i = 2:size(h,3)
                y(:,:,i) = filter2( h(:,:,i), xp(:,:,1), 'same' );
            end
            
        else
            
            % if they have the same number of layers, then do a layer to 
            % filtering
            % (eg, S2 feature is the same stack as the C1 input stack)
            
            y(:,:,2:size(xp,3)) = 0;
            for i = 2:size(xp,3)
                y(:,:,i) = filter2( h(:,:,i), xp(:,:,i), 'same' );
            end
            
        end
    
        
        
    % unpad
    
        r0 = pr + 1;
        rf = r0 + size(x,1) - 1;
        c0 = pc + 1;
        cf = c0 + size(x,2) - 1;

        y = y(r0:rf,c0:cf,:);
    
        
        
end
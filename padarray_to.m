
function x_out = padarray_to( x, out_size, method )

    % h = padarray_to( A, out_size, method );
    % pad's up to the target size
    % or might just trim if you
    %
    % String values for METHOD
    %   a scalar value will just pad with that value, default is zero
    %	'circular'    Pads with circular repetition of elements.
    %   'replicate'   Repeats border elements of A.
    %   'symmetric'   Pads array with mirror reflections of itself. 
    
    demo_mode = false;
    if ~exist('x','var') || isempty(x)
        x = imread('lincoln.jpg');
        x = imresize(x,.25);
        out_size = [2*size(x,1) 2*size(x,2)];
        
        demo_mode = true;
        display('padarray_to is in DEMO MODE');
    end
    
    if length(out_size) < 2
        out_size = [out_size out_size];
    end
    
    if ~exist('method','var') || isempty(method)
        method = 0;
    end
    
    pad_size = out_size - [size(x,1) size(x,2)];
    pad_size = ceil( pad_size/2 );
    
    if ~any( lt(pad_size,0) )
       x_out = padarray(x, pad_size, method);
    else
        x_out = x;
    end
    
    r0 = fix( size(x_out,1)/2 - out_size(1)/2 ) + 1;
    rf = r0 + out_size(1) - 1;
    c0 = fix( size(x_out,2)/2 - out_size(2)/2 ) + 1;
    cf = c0 + out_size(2) - 1;
    % display([ r0 rf c0 cf ]);
    x_out = x_out(r0:rf,c0:cf,:);
    
    if demo_mode
        figure;
        subplot(1,2,1); imshow(x);
        subplot(1,2,2); imshow(x_out);
    end
    
end
   
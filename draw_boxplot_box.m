
function h_out = draw_boxplot_box( x, data_vect, width, outliers )

    % h = draw_boxplot_box( x, data_vect, width, [outliers] );
    %
    % data_vect = [2 25 50 75 98];
    

    hold_was_on = ishold;
    hold on;
    
    % main box
    p_box(1,:) = [ x-.5*width, data_vect(2) ];
    p_box(2,:) = [ x+.5*width, data_vect(2) ];
    p_box(3,:) = [ x+.5*width, data_vect(4) ];
    p_box(4,:) = [ x-.5*width, data_vect(4) ];
    p_box(5,:) = p_box(1,:);
    h.box      = plot(p_box(:,1),p_box(:,2),'k-');
    
    % middle line
    p_mid(1,:) = [x-.5*width, data_vect(3) ];
    p_mid(2,:) = [x+.5*width, data_vect(3) ];
    h.midline  = plot(p_mid(:,1),p_mid(:,2),'r-');
    
    % whiskers
    p_whisker1(1,:) = [ x, data_vect(1) ];
    p_whisker1(2,:) = [ x, data_vect(2) ];
    p_whisker2(1,:) = [ x, data_vect(4) ];
    p_whisker2(2,:) = [ x, data_vect(5) ];
    h.whisker1      = plot( p_whisker1(:,1), p_whisker1(:,2), 'k:' );
    h.whisker2      = plot( p_whisker2(:,1), p_whisker2(:,2), 'k:' );
    
    % caps
    p_cap1(1,:) = [ x-.4*width, data_vect(1) ];
    p_cap1(2,:) = [ x+.4*width, data_vect(1) ];
    p_cap2(1,:) = [ x-.4*width, data_vect(5) ];
    p_cap2(2,:) = [ x+.4*width, data_vect(5) ];
    h.cap1      = plot( p_cap1(:,1), p_cap1(:,2), 'k-' );
    h.cap2      = plot( p_cap2(:,1), p_cap2(:,2), 'k-' );
    
    if exist('outliers','var') && ~isempty(outliers)
        h.outliers = plot(repmat(x,numel(outliers),1), outliers(:), 'ko' );
    end
    
    if ~hold_was_on
        hold off;
    end
    
    if nargout > 0
        h_out = h;
    end
    
end
        
    
    
    
    
    
    
    
    
    
    
    
    

    







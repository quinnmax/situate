

function h = situate_draw_workspace( input, p, workspace )

    % handle_array = situate_draw_workspace( input, p, workspace )
    %
    %   h is the handle to the output figure, specifically the image
    %   input can be an image fname, an image matrix, 
    %       or a handle to an exisiting image
    %   p is a situate parameters structure
    %   workspace is the situate workspace to draw
   

    bounding_box_format_final = 'r';
    bounding_box_format_provisional = 'r--';

    h = [];
    
    switch class(input)
        case 'char'
            x = imresize_px( imread(input), p.image_redim_px );
            h(1) = imshow( x, [] );
        case 'double'
            if all(ishandle(input))
                axes(input);
            else
                x = imresize_px( input, p.image_redim_px );
                h(1) = imshow( x, [] );
            end
        case 'matlab.graphics.axis.Axes'
            axes(input);
        case 'matlab.ui.Figure'
            axes(input.CurrentAxes);
        otherwise
            error('what that?');
    end

    % draw workspace boxes onto main image
    
    hold on;
    for wi = 1:size(workspace.boxes_r0rfc0cf,1)
        if workspace.total_support(wi) >= p.thresholds.total_support_final
            % was UserData.handles(end+1) = 
            h(end+1) = draw_box(workspace.boxes_r0rfc0cf(wi,:), 'r0rfc0cf', bounding_box_format_final);
        else
            % was UserData.handles(end+1) = 
            h(end+1) = draw_box(workspace.boxes_r0rfc0cf(wi,:), 'r0rfc0cf', bounding_box_format_provisional);
        end
    end

    % then draw the text ( so boxes don't cover text )
    for wi = 1:size(workspace.boxes_r0rfc0cf,1)
        label_text = {...
            workspace.labels{wi}; ...
            ['  total: ' num2str(workspace.total_support(wi))]; ...
            ['  gt:    ' num2str(workspace.GT_IOU(wi))]};
        t1 = text( workspace.boxes_r0rfc0cf(wi,3), workspace.boxes_r0rfc0cf(wi,1), label_text);
        set(t1,'color',[0 0 0]);
        set(t1,'FontSize',14);
        set(t1,'FontWeight','bold');
        t2 = text( workspace.boxes_r0rfc0cf(wi,3)+1, workspace.boxes_r0rfc0cf(wi,1)+1, label_text);
        set(t2,'color',[1 1 1]);
        set(t2,'FontSize',14);
        set(t2,'FontWeight','bold');

        %UserData.handles(end+1) = t1;
        %UserData.handles(end+1) = t2;
        h(end+1) = t1;
        h(end+1) = t2;
    end
    hold off;
    
end

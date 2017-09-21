
% save off finished workspaces

%situate_results_directory = '/Users/Max/Dropbox/Projects/situate/results/handshake, test run, single attempt/';

% rcnn_results_directory    = '/Users/Max/Dropbox/Projects/situate/rcnn boxes handshaking/';
% image_directory           = '/Users/Max/Documents/MATLAB/data/situate_images/Handshake_test/';
% output_directory          = '/Users/Max/Desktop/rcnn_results_images/';

% rcnn_results_directory    = '/Users/Max/Dropbox/AAAI2018/AllRcnnResults/dogwalking, positive, portland test';
% image_directory           = '/Users/Max/Documents/MATLAB/data/situate_images/DogWalking_PortlandSimple_test';
% output_directory          = '/Users/Max/Desktop/results images dogwalking rcnn';



for super_i = 1:4


    switch super_i
        case 1
        rcnn_results_directory    = '/Users/Max/Dropbox/AAAI2018/AllRcnnResults/dogwalking, negative, PersonNoDog';
        image_directory           = '/Users/Max/Documents/MATLAB/data/situate_images/DogWalkingSituationNegativeExamples/PersonNoDog';
        output_directory          = '/Users/Max/Desktop/results images dogwalking rcnn';
        fname_preamble = 'PersonNoDog';
        case 2
        rcnn_results_directory    = '/Users/Max/Dropbox/AAAI2018/AllRcnnResults/dogwalking, negative, NoDogNoPerson';
        image_directory           = '/Users/Max/Documents/MATLAB/data/situate_images/DogWalkingSituationNegativeExamples/NoDogNoPerson';
        output_directory          = '/Users/Max/Desktop/results images dogwalking rcnn';
        fname_preamble = 'NoDogNoPerson';
        case 3
        rcnn_results_directory    = '/Users/Max/Dropbox/AAAI2018/AllRcnnResults/dogwalking, negative, DogNoPerson';
        image_directory           = '/Users/Max/Documents/MATLAB/data/situate_images/DogWalkingSituationNegativeExamples/DogNoPerson';
        output_directory          = '/Users/Max/Desktop/results images dogwalking rcnn';
        fname_preamble = 'DogNoPerson';
        case 4
        rcnn_results_directory    = '/Users/Max/Dropbox/AAAI2018/AllRcnnResults/dogwalking, negative, DogAndPerson';
        image_directory           = '/Users/Max/Documents/MATLAB/data/situate_images/DogWalkingSituationNegativeExamples/DogAndPerson';
        output_directory          = '/Users/Max/Desktop/results images dogwalking rcnn';
        fname_preamble = 'DogAndPerson';
    end


if ~exist(output_directory,'dir')
    mkdir(output_directory);
end

[rcnn_confidences, ...
 rcnn_gt_ious, ...
 rcnn_boxes_xywh, ...
 rcnn_output_labels, ...
 rcnn_per_row_fnames] = ...
    rcnn_results_processing.csvs_process( ...
        rcnn_results_directory, ...
        [], ...
        image_directory );

situation_score_function = @(x) prod( x + .01 ) .^ (1/length(x));
rcnn_situation_scores = zeros(length(rcnn_per_row_fnames),1);
for fi = 1:length(rcnn_per_row_fnames)
    rcnn_situation_scores(fi) = situation_score_function(rcnn_confidences(fi,:));
end


rcnn_per_row_fnames_img = cellfun( @(x) [x(1:strfind(x,'.')) 'jpg' ], rcnn_per_row_fnames, 'UniformOutput', false );
rcnn_per_row_fnames_img_w_path = cellfun( @(x) fullfile(image_directory,x),  rcnn_per_row_fnames_img, 'UniformOutput', false );

font_size = 12;
figure
for imi = 1:length(rcnn_per_row_fnames)
%for imi = 1:2
    
    hold off;
    
    cur_im = imread(rcnn_per_row_fnames_img_w_path{imi});
    subplot2(2,3,1,1,2,2);
    imshow(cur_im);
    xlabel(['situation score: ' num2str(rcnn_situation_scores(imi))]);
    hold on;
    
    x_side_position  = size(cur_im,2)+10;
    y_side_positions = linspace( 1, size(cur_im,1), 2 * length(rcnn_output_labels)+1 );
    y_side_positions = y_side_positions(2:2:end-1);
    
    for bi = 1:size(rcnn_boxes_xywh,2)
        draw_box( rcnn_boxes_xywh{imi,bi}, 'xywh', 'LineWidth', 2 );
    end
    for bi = 1:size(rcnn_boxes_xywh,2)
        % label the box itself
        label_text = rcnn_output_labels{bi};
        label_text = strrep( label_text, '_', ' ' );
        
        x_position = rcnn_boxes_xywh{imi,bi}(1);
        y_position = rcnn_boxes_xywh{imi,bi}(2);
        t1 = text( x_position, y_position, label_text);
        set(t1,'color',[eps 0 0]);
        set(t1,'FontSize',font_size);
        set(t1,'FontWeight','bold');
        t2 = text( x_position+1, y_position+1, label_text);
        set(t2,'color',[1-eps 1 1]);
        set(t2,'FontSize',font_size);
        set(t2,'FontWeight','bold');
        
        %set(t2,'BackgroundColor',[0 0 0 .25]);

        % provide details to the right
        detailed_text = {...
            label_text; ...
            ['  confidence : ' sprintf('%0.4f', rcnn_confidences(imi,bi) ) ]; ...
            ['  gt iou     : ' sprintf('%0.4f', rcnn_gt_ious(imi,bi)     ) ]};

        t3 = text( x_side_position, y_side_positions(bi), detailed_text);
        set(t3,'color',[eps 0 0]);
        set(t3,'FontSize',font_size);
        set(t3,'FontWeight','bold');
    
    end
    
    output_fname = sprintf( [fname_preamble '_%03d_rcnn_boxes.png'], imi );
    %output_fname = [rcnn_per_row_fnames_img{imi}(1:strfind(rcnn_per_row_fnames_img{imi},'.')-1) '_rcnn_boxes.png'];
    saveas( gcf, fullfile( output_directory, output_fname ), 'png')
    %close(gcf);
    
    progress(imi,length(rcnn_per_row_fnames));
    
end

end



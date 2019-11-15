imfname = 'dogwalking5.jpg';
im = imread(imfname);
imshow(im);

situate.setup();
tic
data = cnn.cnn_process( im, [1944 2592], 15 );
toc

n = 10;
figure
for ni = 1:n
    subplot_lazy(n,ni)
    imshow( data(:,:,ni), [] );
end


n = 10;
figure
for ni = 1:n
    subplot_lazy(n,ni)
    hist( log(reshape(data(:,:,ni),1,[])), 50 );
end









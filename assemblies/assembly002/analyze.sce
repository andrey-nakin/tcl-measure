screenWidth=1600
screenHeight=800

fileName="result.txt"
M=fscanfMat(fileName);
s=size(M)
m=s(1)
maxTime=M(m)
mMin=min(M(:,2))
mMax=max(M(:,2))
mMean=mean(M(:,2))
mSigma=st_deviation(M(:,2))
printf("Mean\t%f\nMedian\t%f\nSigma\t%f\nMin\t%f\nMax\t%f\n", mMean, median(M(1:m,2)), mSigma, mMin, mMax)

xtitle("Sample", "Time, sec", "Voltage, V")
plot2d(M(1:m, 1), M(1:m, 2))
xset("wpdim", screenWidth/2, screenHeight/2)
xset("wpos", screenWidth/2, 0)

scf()
xtitle("Distribution", "Voltage")
histplot(50, M(:, 2))
nd=rand(10000, 1, 'normal')
for i = 1 : length(nd)
  nd(i) = nd(i) * mSigma + mMean
end
histplot(50, nd(:))
xset("wpdim", screenWidth/2, screenHeight/2)
xset("wpos", 0, screenHeight/2)

scf()
xtitle("Fourier Transform", "Frequency, Hz", "Intensity")
f=fft(M(1:m, 2))
fl=length(f)
for i = 1 : fl
  f(i) = real(f(i)) * real(f(i)) + imag(f(i)) * imag(f(i))
end
x=[0.0 : 1.0 / maxTime : (fl - 1) / maxTime]'
plot2d(x(1:fl/2), f(1:fl/2))
xset("wpdim", screenWidth/2, screenHeight/2)
xset("wpos", screenWidth/2, screenHeight/2)


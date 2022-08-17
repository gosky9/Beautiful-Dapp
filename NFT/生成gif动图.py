import imageio

gif_images = []
for i in range(0, 5):
    gif_images.append(imageio.imread(str(i)+".png"))   # 读取多张图片
imageio.mimsave("hello.gif", gif_images, fps=5)   # 转化为gif动画

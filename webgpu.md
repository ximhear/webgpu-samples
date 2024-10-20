WebGPU에서 **Uniform**, **버퍼**, **샘플러(Sampler)**, **깊이 텍스처(Depth Texture)**를 포함한 초기화 절차를 외우기 쉽게 순서대로 정리해드리겠습니다.

---

### **1. WebGPU 지원 확인**
```javascript
if (!navigator.gpu) {
  console.error("WebGPU를 지원하지 않는 브라우저입니다.");
  return;
}
```

### **2. GPUAdapter 요청**
```javascript
const adapter = await navigator.gpu.requestAdapter();
if (!adapter) {
  console.error("GPU 어댑터를 찾을 수 없습니다.");
  return;
}
```

### **3. GPUDevice 요청**
```javascript
const device = await adapter.requestDevice();
```

### **4. Canvas와 GPUContext 설정**
```javascript
const canvas = document.querySelector("canvas");
const context = canvas.getContext("webgpu");
```

### **5. Canvas 스왑 체인 구성**
```javascript
const swapChainFormat = navigator.gpu.getPreferredCanvasFormat();
context.configure({
  device: device,
  format: swapChainFormat,
  alphaMode: "opaque",
});
```

### **6. 깊이 텍스처(Depth Texture) 생성**
```javascript
const depthTexture = device.createTexture({
  size: [canvas.width, canvas.height],
  format: "depth24plus",
  usage: GPUTextureUsage.RENDER_ATTACHMENT,
});
```

### **7. Uniform 버퍼 생성 및 데이터 업데이트**
- **Uniform 버퍼 생성**
  ```javascript
  const uniformBufferSize = 64; // 4x4 행렬 크기 (64바이트)
  const uniformBuffer = device.createBuffer({
    size: uniformBufferSize,
    usage: GPUBufferUsage.UNIFORM | GPUBufferUsage.COPY_DST,
  });
  ```

- **Uniform 데이터 업데이트**
  ```javascript
  const matrixData = new Float32Array([/* 변환 행렬 데이터 */]);
  device.queue.writeBuffer(uniformBuffer, 0, matrixData.buffer);
  ```

### **8. 버텍스 버퍼 생성**
- **버텍스 데이터 정의 및 버퍼 생성**
  ```javascript
  const vertexData = new Float32Array([
    // 버텍스 포지션 데이터
  ]);
  
  const vertexBuffer = device.createBuffer({
    size: vertexData.byteLength,
    usage: GPUBufferUsage.VERTEX | GPUBufferUsage.COPY_DST,
  });
  
  device.queue.writeBuffer(vertexBuffer, 0, vertexData.buffer);
  ```

### **9. 샘플러(Sampler) 생성**
```javascript
const sampler = device.createSampler({
  magFilter: "linear",
  minFilter: "linear",
});
```

### **10. BindGroupLayout 정의**
- **BindGroupLayout 0: Uniform 버퍼**
  ```javascript
  const bindGroupLayout0 = device.createBindGroupLayout({
    entries: [
      {
        binding: 0,
        visibility: GPUShaderStage.VERTEX,
        buffer: { type: "uniform" },
      },
    ],
  });
  ```

- **BindGroupLayout 1: 텍스처와 샘플러**
  ```javascript
  const bindGroupLayout1 = device.createBindGroupLayout({
    entries: [
      {
        binding: 0,
        visibility: GPUShaderStage.FRAGMENT,
        texture: { sampleType: "float" },
      },
      {
        binding: 1,
        visibility: GPUShaderStage.FRAGMENT,
        sampler: {},
      },
    ],
  });
  ```

### **11. PipelineLayout 정의**
```javascript
const pipelineLayout = device.createPipelineLayout({
  bindGroupLayouts: [bindGroupLayout0, bindGroupLayout1],
});
```

### **12. 셰이더 모듈 생성**
- **셰이더 코드 작성**
  ```wgsl
  @group(0) @binding(0) var<uniform> transformMatrix : mat4x4<f32>;
  @group(1) @binding(0) var textureData : texture_2d<f32>;
  @group(1) @binding(1) var textureSampler : sampler;
  
  @vertex
  fn vs_main(@location(0) position: vec3<f32>) -> @builtin(position) vec4<f32> {
    return transformMatrix * vec4<f32>(position, 1.0);
  }
  
  @fragment
  fn fs_main() -> @location(0) vec4<f32> {
    let texCoords = vec2<f32>(0.5, 0.5);
    return textureSample(textureData, textureSampler, texCoords);
  }
  ```

- **셰이더 모듈 생성**
  ```javascript
  const shaderModule = device.createShaderModule({ code: shaderCode });
  ```

### **13. 렌더 파이프라인 생성 (깊이 텍스처 포함)**
```javascript
const pipeline = device.createRenderPipeline({
  layout: pipelineLayout,
  vertex: {
    module: shaderModule,
    entryPoint: "vs_main",
    buffers: [
      {
        arrayStride: 12, // vec3<f32>의 크기
        attributes: [
          {
            shaderLocation: 0,
            offset: 0,
            format: "float32x3",
          },
        ],
      },
    ],
  },
  fragment: {
    module: shaderModule,
    entryPoint: "fs_main",
    targets: [{ format: swapChainFormat }],
  },
  primitive: {
    topology: "triangle-list",
  },
  depthStencil: {
    format: "depth24plus",
    depthWriteEnabled: true,
    depthCompare: "less",
  },
});
```

### **14. BindGroup 생성**
- **BindGroup 0: Uniform 버퍼**
  ```javascript
  const bindGroup0 = device.createBindGroup({
    layout: bindGroupLayout0,
    entries: [
      {
        binding: 0,
        resource: { buffer: uniformBuffer },
      },
    ],
  });
  ```

- **BindGroup 1: 텍스처와 샘플러**
  ```javascript
  const bindGroup1 = device.createBindGroup({
    layout: bindGroupLayout1,
    entries: [
      {
        binding: 0,
        resource: texture.createView(),
      },
      {
        binding: 1,
        resource: sampler,
      },
    ],
  });
  ```

### **15. 커맨드 버퍼 작성 및 렌더 패스 시작**
```javascript
const commandEncoder = device.createCommandEncoder();
const textureView = context.getCurrentTexture().createView();

const renderPassDescriptor = {
  colorAttachments: [
    {
      view: textureView,
      loadOp: "clear",
      clearValue: { r: 0, g: 0, b: 0, a: 1.0 },
      storeOp: "store",
    },
  ],
  depthStencilAttachment: {
    view: depthTexture.createView(),
    depthLoadOp: "clear",
    depthClearValue: 1.0,
    depthStoreOp: "store",
  },
};

const renderPass = commandEncoder.beginRenderPass(renderPassDescriptor);
```

### **16. 파이프라인 및 BindGroup 설정**
```javascript
renderPass.setPipeline(pipeline);
renderPass.setBindGroup(0, bindGroup0);
renderPass.setBindGroup(1, bindGroup1);
renderPass.setVertexBuffer(0, vertexBuffer);
```

### **17. 그리기 명령 실행**
```javascript
renderPass.draw(vertexCount, instanceCount, firstVertex, firstInstance);
renderPass.end();
```

### **18. 명령 버퍼 제출 및 렌더링 실행**
```javascript
const commandBuffer = commandEncoder.finish();
device.queue.submit([commandBuffer]);
```

---

### **최종 절차 요약**

1. **WebGPU 지원 확인**: `navigator.gpu` 체크
2. **GPUAdapter 요청**: `navigator.gpu.requestAdapter()`
3. **GPUDevice 요청**: `adapter.requestDevice()`
4. **Canvas와 GPUContext 설정**: `canvas.getContext("webgpu")`
5. **Canvas 스왑 체인 구성**: `context.configure()`
6. **깊이 텍스처 생성**: `device.createTexture()`
7. **Uniform 버퍼 생성 및 데이터 업데이트**: `device.createBuffer()`, `device.queue.writeBuffer()`
8. **버텍스 버퍼 생성**: `device.createBuffer()`, `device.queue.writeBuffer()`
9. **샘플러 생성**: `device.createSampler()`
10. **BindGroupLayout 정의**: `device.createBindGroupLayout()`
11. **PipelineLayout 정의**: `device.createPipelineLayout()`
12. **셰이더 모듈 생성**: `device.createShaderModule()`
13. **렌더 파이프라인 생성**: `device.createRenderPipeline()`
14. **BindGroup 생성**: `device.createBindGroup()`
15. **커맨드 버퍼 작성 및 렌더 패스 시작**: `device.createCommandEncoder()`, `commandEncoder.beginRenderPass()`
16. **파이프라인 및 BindGroup 설정**: `renderPass.setPipeline()`, `renderPass.setBindGroup()`
17. **그리기 명령 실행**: `renderPass.draw()`, `renderPass.end()`
18. **명령 버퍼 제출 및 렌더링 실행**: `device.queue.submit()`

---

이 순서를 기억하시면 WebGPU에서 **Uniform**, **버퍼**, **샘플러**, **깊이 텍스처**를 포함한 초기화 과정을 효율적으로 수행할 수 있습니다. 각 단계에서 중요한 함수와 설정에 집중하여 연습해보세요.

@extends('layouts.admin')

@section('title')
    Panel Banner
@endsection

@section('content-header')
    <h1>Panel Banner<small>Atur banner informasi di halaman client.</small></h1>
    <ol class="breadcrumb">
        <li><a href="{{ url('/admin') }}">Admin</a></li>
        <li class="active">Panel Banner</li>
    </ol>
@endsection

@section('content')
    <div class="row">
        <div class="col-xs-12">
            @if (session('success'))
                <div class="alert alert-success">
                    {{ session('success') }}
                </div>
            @endif

            @if ($errors->any())
                <div class="alert alert-danger">
                    <strong>Gagal menyimpan pengaturan.</strong>
                    <ul style="margin-top: 8px;">
                        @foreach ($errors->all() as $error)
                            <li>{{ $error }}</li>
                        @endforeach
                    </ul>
                </div>
            @endif

            <div class="box box-primary">
                <div class="box-header with-border">
                    <h3 class="box-title">Pengaturan Banner</h3>
                </div>

                <form method="POST" action="{{ url('/admin/banner') }}">
                    @csrf

                    <div class="box-body">
                        <div class="checkbox">
                            <label>
                                <input type="checkbox" name="enabled" value="1" {{ old('enabled', $banner->enabled) ? 'checked' : '' }}>
                                Aktifkan banner
                            </label>
                        </div>

                        <div class="form-group">
                            <label for="type">Jenis Banner</label>
                            <select id="type" name="type" class="form-control">
                                <option value="info" {{ old('type', $banner->type) === 'info' ? 'selected' : '' }}>Informasi</option>
                                <option value="warning" {{ old('type', $banner->type) === 'warning' ? 'selected' : '' }}>Warning</option>
                                <option value="promo" {{ old('type', $banner->type) === 'promo' ? 'selected' : '' }}>Promosi</option>
                            </select>
                            <p class="text-muted" style="margin-top: 6px;">Informasi = biru, Warning = kuning, Promosi = hijau.</p>
                        </div>

                        <div class="form-group">
                            <label for="title">Judul Banner</label>
                            <input
                                id="title"
                                type="text"
                                name="title"
                                class="form-control"
                                maxlength="120"
                                value="{{ old('title', $banner->title) }}"
                                placeholder="Contoh: Maintenance Panel"
                            >
                        </div>

                        <div class="form-group">
                            <label for="message">Isi Banner</label>
                            <textarea
                                id="message"
                                name="message"
                                class="form-control"
                                rows="5"
                                maxlength="1000"
                                placeholder="Tulis isi banner di sini..."
                            >{{ old('message', $banner->message) }}</textarea>
                        </div>

                        <div class="callout callout-info">
                            <h4>Preview perilaku banner</h4>
                            <p>Banner dapat ditutup dengan tombol X oleh user. Setelah halaman di-refresh, web dibuka ulang, atau user login ulang, banner akan tampil kembali.</p>
                        </div>
                    </div>

                    <div class="box-footer">
                        <button type="submit" class="btn btn-primary">Simpan Banner</button>
                        <a href="{{ url('/') }}" target="_blank" class="btn btn-default">Lihat Halaman Client</a>
                    </div>
                </form>
            </div>
        </div>
    </div>
@endsection
